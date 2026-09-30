revoke all on function public.log_audit_event(text,text,uuid,jsonb) from anon;
revoke all on function public.log_audit_event(text,text,uuid,jsonb) from public;
grant execute on function public.log_audit_event(text,text,uuid,jsonb) to authenticated;
create index if not exists audit_events_actor_created_idx on public.audit_events(actor_id,created_at desc);