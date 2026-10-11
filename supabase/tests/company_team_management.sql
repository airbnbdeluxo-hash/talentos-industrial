-- Run with `supabase test db` after applying migrations to a disposable database.
do $$
declare
  function_name text;
  definition text;
begin
  if not exists (
    select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relname='company_invitations' and c.relrowsecurity
  ) then raise exception 'company_invitations must have RLS enabled'; end if;

  if has_table_privilege('anon','public.company_invitations','select')
     or has_table_privilege('authenticated','public.company_invitations','select') then
    raise exception 'company_invitations must only be readable by the server';
  end if;
  if has_table_privilege('authenticated','public.company_members','update')
     or has_table_privilege('authenticated','public.company_members','delete') then
    raise exception 'browser clients must not change or remove company_members directly';
  end if;

  -- These browser RPCs were removed; passing their names to
  -- has_function_privilege raises undefined_function before the absence check.
  if to_regprocedure('public.company_team_update_member_role(uuid,uuid,text)') is not null
     or to_regprocedure('public.company_team_remove_member(uuid,uuid)') is not null
     or to_regprocedure('public.company_team_transfer_owner(uuid,uuid)') is not null
     or to_regprocedure('public.accept_company_invitation(uuid)') is not null then
    raise exception 'browser-callable team security definer functions must be removed';
  end if;

  foreach function_name in array array[
    'company_team_create_company_service',
    'company_team_accept_invitation_service',
    'company_team_update_member_role_service',
    'company_team_remove_member_service',
    'company_team_transfer_owner_service'
  ] loop
    select pg_get_functiondef(p.oid) into definition
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname=function_name;
    if definition is null or definition not like '%SECURITY DEFINER%' or definition not like '%search_path%' then
      raise exception 'server team function % must be security definer with pinned search_path',function_name;
    end if;
  end loop;

  if has_function_privilege('authenticated','public.company_team_create_company_service(uuid,text,text,text,text,integer,text)','execute')
     or has_function_privilege('authenticated','public.company_team_accept_invitation_service(uuid,text,uuid)','execute')
     or has_function_privilege('authenticated','public.company_team_update_member_role_service(uuid,uuid,uuid,text)','execute')
     or has_function_privilege('authenticated','public.company_team_remove_member_service(uuid,uuid,uuid)','execute')
     or has_function_privilege('authenticated','public.company_team_transfer_owner_service(uuid,uuid,uuid)','execute') then
    raise exception 'server-only team functions must not be executable by authenticated clients';
  end if;
end $$;
