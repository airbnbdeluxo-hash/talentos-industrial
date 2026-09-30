-- Require a normalized CNPJ for self-service company onboarding.
-- The Edge Function validates CNPJ check digits; this function enforces normalized
-- storage and uniqueness inside the same transaction that creates the Owner.

create or replace function public.company_team_create_company_service(
  p_actor_id uuid,
  p_name text,
  p_cnpj text,
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

  if p_cnpj !~ '^[0-9]{14}$' then
    raise exception 'invalid company cnpj';
  end if;

  if exists (
    select 1 from public.companies c where c.cnpj = p_cnpj
  ) then
    raise exception 'company cnpj already registered';
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
    name, cnpj, city, state, industry, created_by, city_ibge_code
  )
  values(
    trim(p_name),
    p_cnpj,
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

revoke all on function public.company_team_create_company_service(uuid,text,text,text,text,integer,text) from public, anon, authenticated;
grant execute on function public.company_team_create_company_service(uuid,text,text,text,text,integer,text) to service_role;
