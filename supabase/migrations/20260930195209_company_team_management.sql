-- Company team administration. Membership writes happen only through guarded
-- server functions; browser roles never receive direct INSERT/UPDATE/DELETE.

create table if not exists public.company_invitations (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  invited_email text not null,
  invited_user_id uuid references public.profiles(id) on delete set null,
  member_role text not null check (member_role in ('recruiter','viewer')),
  status text not null default 'pending' check (status in ('pending','accepted','revoked','expired')),
  invited_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '7 days'),
  accepted_at timestamptz,
  accepted_by uuid references public.profiles(id) on delete set null
);

create index if not exists idx_company_invitations_company_status
  on public.company_invitations(company_id,status,created_at desc);
create unique index if not exists idx_company_invitations_pending_email
  on public.company_invitations(company_id,lower(invited_email)) where status='pending';

alter table public.company_invitations enable row level security;
revoke all on public.company_invitations from public,anon,authenticated;
grant all on public.company_invitations to service_role;
revoke update,delete on public.company_members from authenticated;
grant select,insert on public.company_members to authenticated;

-- The owner changes a recruiter's or viewer's role. Owners are changed only
-- through the explicit transfer function below.
create or replace function public.company_team_update_member_role(
  p_company_id uuid, p_user_id uuid, p_member_role text
) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if (select auth.uid()) is null then raise exception 'authentication required'; end if;
  if p_member_role not in ('recruiter','viewer') then raise exception 'invalid member role'; end if;
  if not exists (
    select 1 from public.company_members cm
    where cm.company_id=p_company_id and cm.user_id=(select auth.uid()) and cm.member_role='owner'
  ) then raise exception 'not authorized to manage company team'; end if;
  update public.company_members
     set member_role=p_member_role
   where company_id=p_company_id and user_id=p_user_id and member_role in ('recruiter','viewer');
  if not found then raise exception 'team member not found'; end if;
end;
$$;

create or replace function public.company_team_remove_member(
  p_company_id uuid, p_user_id uuid
) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if (select auth.uid()) is null then raise exception 'authentication required'; end if;
  if not exists (
    select 1 from public.company_members cm
    where cm.company_id=p_company_id and cm.user_id=(select auth.uid()) and cm.member_role='owner'
  ) then raise exception 'not authorized to manage company team'; end if;
  delete from public.company_members
   where company_id=p_company_id and user_id=p_user_id and member_role in ('recruiter','viewer');
  if not found then raise exception 'team member not found'; end if;
  update public.company_invitations
     set status='revoked'
   where company_id=p_company_id and invited_user_id=p_user_id and status='pending';
end;
$$;

create or replace function public.company_team_transfer_owner(
  p_company_id uuid, p_new_owner_id uuid
) returns void
language plpgsql security definer set search_path = '' as $$
declare v_old_owner uuid := (select auth.uid());
begin
  if v_old_owner is null then raise exception 'authentication required'; end if;
  if p_new_owner_id=v_old_owner then raise exception 'new owner must be another team member'; end if;
  if not exists (
    select 1 from public.company_members cm
    where cm.company_id=p_company_id and cm.user_id=v_old_owner and cm.member_role='owner'
  ) then raise exception 'not authorized to transfer company ownership'; end if;
  if not exists (
    select 1 from public.company_members cm
    where cm.company_id=p_company_id and cm.user_id=p_new_owner_id and cm.member_role in ('recruiter','viewer')
  ) then raise exception 'new owner must already be a recruiter or viewer'; end if;
  update public.company_members set member_role='recruiter'
   where company_id=p_company_id and user_id=v_old_owner and member_role='owner';
  update public.company_members set member_role='owner'
   where company_id=p_company_id and user_id=p_new_owner_id;
  update public.companies set created_by=p_new_owner_id where id=p_company_id;
end;
$$;

create or replace function public.accept_company_invitation(p_invitation_id uuid)
returns public.company_members
language plpgsql security definer set search_path = '' as $$
declare v_inv public.company_invitations%rowtype; v_user uuid := (select auth.uid()); v_email text;
begin
  if v_user is null then raise exception 'authentication required'; end if;
  v_email := lower(coalesce((select auth.jwt()->>'email'),''));
  select * into v_inv from public.company_invitations where id=p_invitation_id for update;
  if not found or v_inv.status<>'pending' then raise exception 'invitation is unavailable'; end if;
  if v_inv.expires_at<=now() then
    update public.company_invitations set status='expired' where id=v_inv.id;
    raise exception 'invitation expired';
  end if;
  if v_email='' or v_email<>lower(v_inv.invited_email) then raise exception 'invitation email does not match'; end if;
  if v_inv.invited_user_id is not null and v_inv.invited_user_id<>v_user then raise exception 'invitation belongs to another account'; end if;
  insert into public.company_members(company_id,user_id,member_role)
  values(v_inv.company_id,v_user,v_inv.member_role)
  on conflict(company_id,user_id) do update set member_role=excluded.member_role
  where public.company_members.member_role in ('recruiter','viewer');
  if not exists(select 1 from public.company_members where company_id=v_inv.company_id and user_id=v_user) then
    raise exception 'could not add account to company team';
  end if;
  update public.company_invitations set status='accepted',accepted_at=now(),accepted_by=v_user,invited_user_id=v_user where id=v_inv.id;
  update public.profiles set role='empresa' where id=v_user and role='candidato';
  return (select cm from public.company_members cm where cm.company_id=v_inv.company_id and cm.user_id=v_user);
end;
$$;

revoke all on function public.company_team_update_member_role(uuid,uuid,text) from public,anon;
revoke all on function public.company_team_remove_member(uuid,uuid) from public,anon;
revoke all on function public.company_team_transfer_owner(uuid,uuid) from public,anon;
revoke all on function public.accept_company_invitation(uuid) from public,anon;
grant execute on function public.company_team_update_member_role(uuid,uuid,text) to authenticated;
grant execute on function public.company_team_remove_member(uuid,uuid) to authenticated;
grant execute on function public.company_team_transfer_owner(uuid,uuid) to authenticated;
grant execute on function public.accept_company_invitation(uuid) to authenticated;
