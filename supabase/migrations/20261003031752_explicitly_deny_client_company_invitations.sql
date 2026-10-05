revoke all on table public.company_invitations from anon, authenticated;

drop policy if exists company_invitations_client_deny on public.company_invitations;
create policy company_invitations_client_deny
on public.company_invitations
for all
to anon, authenticated
using (false)
with check (false);
