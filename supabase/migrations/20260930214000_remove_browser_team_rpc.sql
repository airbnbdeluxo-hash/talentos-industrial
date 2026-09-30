-- Remove browser-callable SECURITY DEFINER team RPCs after the web client
-- has moved all privileged mutations to the company-team Edge Function.

revoke all on function public.company_team_update_member_role(uuid,uuid,text) from public, anon, authenticated;
revoke all on function public.company_team_remove_member(uuid,uuid) from public, anon, authenticated;
revoke all on function public.company_team_transfer_owner(uuid,uuid) from public, anon, authenticated;
revoke all on function public.accept_company_invitation(uuid) from public, anon, authenticated;

drop function if exists public.company_team_update_member_role(uuid,uuid,text);
drop function if exists public.company_team_remove_member(uuid,uuid);
drop function if exists public.company_team_transfer_owner(uuid,uuid);
drop function if exists public.accept_company_invitation(uuid);
