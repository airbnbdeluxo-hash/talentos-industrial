create table if not exists public.audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid null references auth.users(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
alter table public.audit_events enable row level security;
drop policy if exists "audit_events_admin_select" on public.audit_events;
create policy "audit_events_admin_select" on public.audit_events for select to authenticated
using (exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='admin'));

create or replace function public.log_audit_event(
  p_action text, p_entity_type text, p_entity_id uuid default null, p_metadata jsonb default '{}'::jsonb
) returns void language plpgsql security definer set search_path=public as $$
begin
  insert into public.audit_events(actor_id,action,entity_type,entity_id,metadata)
  values ((select auth.uid()), p_action, p_entity_type, p_entity_id, coalesce(p_metadata,'{}'::jsonb));
end; $$;
revoke all on function public.log_audit_event(text,text,uuid,jsonb) from public;
grant execute on function public.log_audit_event(text,text,uuid,jsonb) to authenticated;

create or replace function public.update_job_alert(
  p_alert_id uuid, p_active boolean
) returns public.job_alerts language plpgsql security invoker set search_path=public as $$
declare row public.job_alerts;
begin
  update public.job_alerts
  set active=p_active, updated_at=now()
  where id=p_alert_id and candidate_id=(select auth.uid())
  returning * into row;
  if row.id is null then raise exception 'Alerta não encontrado ou sem permissão'; end if;
  perform public.log_audit_event(case when p_active then 'job_alert_activated' else 'job_alert_paused' end,'job_alerts',row.id,jsonb_build_object('active',p_active));
  return row;
end; $$;
revoke all on function public.update_job_alert(uuid,boolean) from public;
grant execute on function public.update_job_alert(uuid,boolean) to authenticated;

create or replace function public.reschedule_interview(
  p_interview_id uuid, p_scheduled_at timestamptz, p_duration_minutes integer,
  p_mode text, p_location text default null, p_meeting_url text default null
) returns public.interviews language plpgsql security invoker set search_path=public as $$
declare row public.interviews; old_row public.interviews;
begin
  if p_scheduled_at <= now() then raise exception 'A nova data da entrevista deve ser futura'; end if;
  if p_duration_minutes < 15 or p_duration_minutes > 240 then raise exception 'Duração inválida'; end if;
  select * into old_row from public.interviews where id=p_interview_id;
  if old_row.id is null then raise exception 'Entrevista não encontrada'; end if;
  if not (
    old_row.interviewer_id=(select auth.uid())
    or exists (
      select 1 from public.applications a
      join public.jobs j on j.id=a.job_id
      join public.company_members cm on cm.company_id=j.company_id
      where a.id=old_row.application_id and cm.user_id=(select auth.uid()) and cm.member_role in ('owner','recruiter')
    )
    or exists (select 1 from public.applications a where a.id=old_row.application_id and a.candidate_id=(select auth.uid()))
  ) then raise exception 'Sem permissão para reagendar esta entrevista'; end if;
  if old_row.status='cancelada' then raise exception 'Entrevista cancelada não pode ser reagendada'; end if;
  update public.interviews set
    scheduled_at=p_scheduled_at,duration_minutes=p_duration_minutes,
    mode=case when p_mode in ('online','presencial') then p_mode else old_row.mode end,
    location=nullif(trim(coalesce(p_location,'')),''),
    meeting_url=nullif(trim(coalesce(p_meeting_url,'')),''),
    status='agendada',updated_at=now()
  where id=p_interview_id returning * into row;
  perform public.log_audit_event('interview_rescheduled','interviews',row.id,jsonb_build_object('from',old_row.scheduled_at,'to',row.scheduled_at,'application_id',row.application_id));
  return row;
end; $$;
revoke all on function public.reschedule_interview(uuid,timestamptz,integer,text,text,text) from public;
grant execute on function public.reschedule_interview(uuid,timestamptz,integer,text,text,text) to authenticated;
