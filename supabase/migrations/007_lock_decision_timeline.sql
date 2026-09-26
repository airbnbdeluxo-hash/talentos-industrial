-- Final security hardening for decision timeline
revoke execute on function public.log_application_event() from anon, authenticated, public;
create index if not exists idx_application_events_actor on public.application_events(actor_id);
