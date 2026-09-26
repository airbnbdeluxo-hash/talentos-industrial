-- Prevent self-service changes to the account role after signup.
create or replace function public.prevent_profile_role_change()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if old.role is distinct from new.role
     and coalesce(current_setting('request.jwt.claim.role', true),'') not in ('service_role','supabase_admin')
     and current_user not in ('postgres','supabase_admin') then
    raise exception 'profile role is immutable';
  end if;
  return new;
end;
$$;

drop trigger if exists protect_profile_role on public.profiles;
create trigger protect_profile_role
before update on public.profiles
for each row execute function public.prevent_profile_role_change();

drop policy if exists profile_self on public.profiles;
create policy profile_self_select on public.profiles
for select to authenticated
using ((select auth.uid())=id);

create policy profile_self_update on public.profiles
for update to authenticated
using ((select auth.uid())=id)
with check ((select auth.uid())=id);