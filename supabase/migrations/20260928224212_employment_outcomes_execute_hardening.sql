-- TalentOS: remove default PUBLIC execution from the post-hire outcome RPC.
revoke execute on function public.record_employment_outcome(uuid,text,numeric,smallint,text,jsonb,text) from public;
revoke execute on function public.record_employment_outcome(uuid,text,numeric,smallint,text,jsonb,text) from anon;
grant execute on function public.record_employment_outcome(uuid,text,numeric,smallint,text,jsonb,text) to authenticated;
