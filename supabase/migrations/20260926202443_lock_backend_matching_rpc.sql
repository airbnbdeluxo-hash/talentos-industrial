-- Keep the backend matching RPC out of the anonymous API surface.
revoke execute on function public.generate_matches_for_job(uuid) from anon;
revoke execute on function public.generate_matches_for_job(uuid) from public;
grant execute on function public.generate_matches_for_job(uuid) to authenticated;