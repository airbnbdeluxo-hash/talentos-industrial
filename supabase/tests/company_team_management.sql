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

  if has_function_privilege('anon','public.company_team_update_member_role(uuid,uuid,text)','execute')
     or has_function_privilege('anon','public.company_team_remove_member(uuid,uuid)','execute')
     or has_function_privilege('anon','public.company_team_transfer_owner(uuid,uuid)','execute')
     or has_function_privilege('anon','public.accept_company_invitation(uuid)','execute') then
    raise exception 'anonymous users must not execute company team functions';
  end if;
  if not has_function_privilege('authenticated','public.company_team_update_member_role(uuid,uuid,text)','execute')
     or not has_function_privilege('authenticated','public.company_team_remove_member(uuid,uuid)','execute')
     or not has_function_privilege('authenticated','public.company_team_transfer_owner(uuid,uuid)','execute')
     or not has_function_privilege('authenticated','public.accept_company_invitation(uuid)','execute') then
    raise exception 'authenticated team functions are missing';
  end if;

  foreach function_name in array array[
    'company_team_update_member_role','company_team_remove_member',
    'company_team_transfer_owner','accept_company_invitation'
  ] loop
    select pg_get_functiondef(p.oid) into definition
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname=function_name;
    if definition is null or definition not like '%auth.uid()%' or definition not like '%search_path%' then
      raise exception 'team function % must bind the caller and pin search_path',function_name;
    end if;
  end loop;
end $$;
