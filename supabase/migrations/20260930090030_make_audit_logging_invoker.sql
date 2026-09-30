create policy "audit_events_authenticated_insert" on public.audit_events for insert to authenticated with check (actor_id=(select auth.uid()));
create or replace function public.log_audit_event(
  p_action text, p_entity_type text, p_entity_id uuid default null, p_metadata jsonb default '{}'::jsonb
) returns void language plpgsql security invoker set search_path=public as $$
begin
  insert into public.audit_events(actor_id,action,entity_type,entity_id,metadata)
  values ((select auth.uid()), p_action, p_entity_type, p_entity_id, coalesce(p_metadata,'{}'::jsonb));
end; $$;
revoke all on function public.log_audit_event(text,text,uuid,jsonb) from public;
grant execute on function public.log_audit_event(text,text,uuid,jsonb) to authenticated;