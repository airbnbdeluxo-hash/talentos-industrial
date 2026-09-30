-- Server-only company onboarding and team mutations.
-- These functions are invoked only by the authenticated company-team Edge Function
-- using the service role. Browser roles receive no EXECUTE privilege.

create or replace function public.company_team_create_company_service(
  p_actor_id uuid,
  p_name text,
  p_city text,
  p_state text,
  p_city_ibge_code integer,
  p_industry text
) returns public.companies
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_company public.companies%rowtype;
begin
  if p_actor_id is null or not exists (
    select 1 from public.profiles p where p.id = p_actor_id
  ) then
    raise exception 'profile not found';
  end if;

  if exists (
    select 1 from public.company_members cm where cm.user_id = p_actor_id
  ) then
    raise exception 'account already belongs to a company';
  end if;

  if nullif(trim(p_name), '') is null or length(trim(p_name)) > 160 then
    raise exception 'invalid company name';
  end if;

  if not exists (
    select 1
    from public.brazil_cities bc
    where bc.ibge_code = p_city_ibge_code
      and upper(trim(bc.uf)) = upper(trim(p_state))
      and (bc.name || ' — ' || trim(bc.uf)) = p_city
  ) then
    raise exception 'invalid company city';
  end if;

  insert into public.companies(
    name, city, state, industry, created_by, city_ibge_code
  )
  values(
    trim(p_name),
    p_city,
    upper(trim(p_state)),
    nullif(trim(p_industry), ''),
    p_actor_id,
    p_city_ibge_code
  )
  returning * into v_company;

  insert into public.company_members(company_id, user_id, member_role)
  values(v_company.id, p_actor_id, 'owner');

  update public.profiles
     set role = 'empresa'
   where id = p_actor_id;

  return v_company;
end;
$$;

create or replace function public.company_team_accept_invitation_service(
  p_actor_id uuid,
  p_actor_email text,
  p_invitation_id uuid
) returns public.company_members
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_inv public.company_invitations%rowtype;
  v_member public.company_members%rowtype;
begin
  if p_actor_id is null or nullif(lower(trim(p_actor_email)), '') is null then
    raise exception 'authentication required';
  end if;

  select *
    into v_inv
    from public.company_invitations
   where id = p_invitation_id
   for update;

  if not found or v_inv.status <> 'pending' then
    raise exception 'invitation is unavailable';
  end if;

  if v_inv.expires_at <= now() then
    update public.company_invitations
       set status = 'expired'
     where id = v_inv.id;
    raise exception 'invitation expired';
  end if;

  if lower(trim(p_actor_email)) <> lower(v_inv.invited_email) then
    raise exception 'invitation email does not match';
  end if;

  if v_inv.invited_user_id is not null and v_inv.invited_user_id <> p_actor_id then
    raise exception 'invitation belongs to another account';
  end if;

  insert into public.company_members(company_id, user_id, member_role)
  values(v_inv.company_id, p_actor_id, v_inv.member_role)
  on conflict(company_id, user_id) do update
    set member_role = excluded.member_role
  where public.company_members.member_role in ('recruiter','viewer')
  returning * into v_member;

  if v_member.company_id is null then
    select *
      into v_member
      from public.company_members
     where company_id = v_inv.company_id
       and user_id = p_actor_id;
  end if;

  if v_member.company_id is null then
    raise exception 'could not add account to company team';
  end if;

  update public.company_invitations
     set status = 'accepted',
         accepted_at = now(),
         accepted_by = p_actor_id,
         invited_user_id = p_actor_id
   where id = v_inv.id;

  update public.profiles
     set role = 'empresa'
   where id = p_actor_id
     and role = 'candidato';

  return v_member;
end;
$$;

create or replace function public.company_team_update_member_role_service(
  p_actor_id uuid,
  p_company_id uuid,
  p_user_id uuid,
  p_member_role text
) returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_member_role not in ('recruiter','viewer') then
    raise exception 'invalid member role';
  end if;

  if not exists (
    select 1
      from public.company_members cm
     where cm.company_id = p_company_id
       and cm.user_id = p_actor_id
       and cm.member_role = 'owner'
  ) then
    raise exception 'not authorized to manage company team';
  end if;

  update public.company_members
     set member_role = p_member_role
   where company_id = p_company_id
     and user_id = p_user_id
     and member_role in ('recruiter','viewer');

  if not found then
    raise exception 'team member not found';
  end if;
end;
$$;

create or replace function public.company_team_remove_member_service(
  p_actor_id uuid,
  p_company_id uuid,
  p_user_id uuid
) returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1
      from public.company_members cm
     where cm.company_id = p_company_id
       and cm.user_id = p_actor_id
       and cm.member_role = 'owner'
  ) then
    raise exception 'not authorized to manage company team';
  end if;

  delete from public.company_members
   where company_id = p_company_id
     and user_id = p_user_id
     and member_role in ('recruiter','viewer');

  if not found then
    raise exception 'team member not found';
  end if;

  update public.company_invitations
     set status = 'revoked'
   where company_id = p_company_id
     and invited_user_id = p_user_id
     and status = 'pending';
end;
$$;

create or replace function public.company_team_transfer_owner_service(
  p_actor_id uuid,
  p_company_id uuid,
  p_new_owner_id uuid
) returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_new_owner_id = p_actor_id then
    raise exception 'new owner must be another team member';
  end if;

  if not exists (
    select 1
      from public.company_members cm
     where cm.company_id = p_company_id
       and cm.user_id = p_actor_id
       and cm.member_role = 'owner'
  ) then
    raise exception 'not authorized to transfer company ownership';
  end if;

  if not exists (
    select 1
      from public.company_members cm
     where cm.company_id = p_company_id
       and cm.user_id = p_new_owner_id
       and cm.member_role in ('recruiter','viewer')
  ) then
    raise exception 'new owner must already be a recruiter or viewer';
  end if;

  update public.company_members
     set member_role = 'recruiter'
   where company_id = p_company_id
     and user_id = p_actor_id
     and member_role = 'owner';

  update public.company_members
     set member_role = 'owner'
   where company_id = p_company_id
     and user_id = p_new_owner_id;

  update public.companies
     set created_by = p_new_owner_id
   where id = p_company_id;
end;
$$;

revoke all on function public.company_team_create_company_service(uuid,text,text,text,integer,text) from public, anon, authenticated;
revoke all on function public.company_team_accept_invitation_service(uuid,text,uuid) from public, anon, authenticated;
revoke all on function public.company_team_update_member_role_service(uuid,uuid,uuid,text) from public, anon, authenticated;
revoke all on function public.company_team_remove_member_service(uuid,uuid,uuid) from public, anon, authenticated;
revoke all on function public.company_team_transfer_owner_service(uuid,uuid,uuid) from public, anon, authenticated;

grant execute on function public.company_team_create_company_service(uuid,text,text,text,integer,text) to service_role;
grant execute on function public.company_team_accept_invitation_service(uuid,text,uuid) to service_role;
grant execute on function public.company_team_update_member_role_service(uuid,uuid,uuid,text) to service_role;
grant execute on function public.company_team_remove_member_service(uuid,uuid,uuid) to service_role;
grant execute on function public.company_team_transfer_owner_service(uuid,uuid,uuid) to service_role;
