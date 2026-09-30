-- TalentOS Industrial: secure candidate actions and scheduled recruitment reminders

create or replace function public.respond_to_offer(p_offer_id uuid,p_status text)
returns public.offers
language plpgsql
security definer
set search_path=public
as $$
declare result_row public.offers;
begin
  if p_status not in ('aceita','recusada') then raise exception 'invalid offer status'; end if;
  update public.offers o
  set status=p_status,responded_at=now(),updated_at=now()
  where o.id=p_offer_id
    and exists(select 1 from public.applications a where a.id=o.application_id and a.candidate_id=(select auth.uid()))
  returning o.* into result_row;
  if result_row.id is null then raise exception 'not authorized for this offer'; end if;
  return result_row;
end;
$$;
revoke all on function public.respond_to_offer(uuid,text) from public;
grant execute on function public.respond_to_offer(uuid,text) to authenticated;

create or replace function public.respond_to_interview(p_interview_id uuid,p_status text)
returns public.interviews
language plpgsql
security definer
set search_path=public
as $$
declare result_row public.interviews;
begin
  if p_status not in ('confirmada','cancelada') then raise exception 'invalid interview status'; end if;
  update public.interviews i
  set status=p_status,updated_at=now()
  where i.id=p_interview_id
    and exists(select 1 from public.applications a where a.id=i.application_id and a.candidate_id=(select auth.uid()))
  returning i.* into result_row;
  if result_row.id is null then raise exception 'not authorized for this interview'; end if;
  return result_row;
end;
$$;
revoke all on function public.respond_to_interview(uuid,text) from public;
grant execute on function public.respond_to_interview(uuid,text) to authenticated;

create or replace function public.get_application_contact(p_application_id uuid)
returns uuid
language sql
security definer
set search_path=public
as $$
  select cm.user_id
  from public.applications a
  join public.jobs j on j.id=a.job_id
  join public.company_members cm on cm.company_id=j.company_id
  where a.id=p_application_id
    and a.candidate_id=(select auth.uid())
    and cm.member_role in ('owner','recruiter')
  order by cm.member_role='owner' desc,cm.created_at asc
  limit 1;
$$;
revoke all on function public.get_application_contact(uuid) from public;
grant execute on function public.get_application_contact(uuid) to authenticated;

drop policy if exists offers_update on public.offers;
create policy offers_update on public.offers for update to authenticated
using(created_by=(select auth.uid()))
with check(created_by=(select auth.uid()));

create or replace function public.send_recruitment_reminders()
returns void
language plpgsql
security definer
set search_path=public
as $$
declare app_row record; cm_row record; int_row record;
begin
  for app_row in
    select a.id,a.job_id,a.status,a.updated_at,j.title,j.company_id
    from public.applications a join public.jobs j on j.id=a.job_id
    where a.status in ('novo','triagem','entrevista','aprovado')
      and a.updated_at < now()-interval '3 days'
  loop
    for cm_row in select cm.user_id from public.company_members cm where cm.company_id=app_row.company_id and cm.member_role in ('owner','recruiter')
    loop
      if not exists(select 1 from public.notifications n where n.user_id=cm_row.user_id and n.kind='processo_parado' and n.created_at::date=current_date and n.body like '%'||app_row.id::text||'%') then
        insert into public.notifications(user_id,kind,title,body,href)
        values(cm_row.user_id,'processo_parado','Candidatura aguardando ação','A candidatura '||app_row.id::text||' para '||app_row.title||' está há mais de 3 dias sem mudança de etapa.','/');
      end if;
    end loop;
  end loop;

  for int_row in
    select i.id,i.application_id,i.scheduled_at,a.candidate_id,j.title,i.interviewer_id
    from public.interviews i join public.applications a on a.id=i.application_id join public.jobs j on j.id=a.job_id
    where i.status in ('agendada','confirmada') and i.scheduled_at between now() and now()+interval '24 hours'
  loop
    if not exists(select 1 from public.notifications n where n.user_id=int_row.candidate_id and n.kind='entrevista' and n.created_at::date=current_date and n.body like '%'||int_row.id::text||'%') then
      insert into public.notifications(user_id,kind,title,body,href)
      values(int_row.candidate_id,'entrevista','Entrevista nas próximas 24 horas','A entrevista '||int_row.id::text||' para '||int_row.title||' está marcada para '||to_char(int_row.scheduled_at at time zone 'America/Sao_Paulo','DD/MM/YYYY HH24:MI'),'/' );
    end if;
    if int_row.interviewer_id is not null and not exists(select 1 from public.notifications n where n.user_id=int_row.interviewer_id and n.kind='entrevista' and n.created_at::date=current_date and n.body like '%'||int_row.id::text||'%') then
      insert into public.notifications(user_id,kind,title,body,href)
      values(int_row.interviewer_id,'entrevista','Entrevista nas próximas 24 horas','A entrevista '||int_row.id::text||' para '||int_row.title||' está marcada para '||to_char(int_row.scheduled_at at time zone 'America/Sao_Paulo','DD/MM/YYYY HH24:MI'),'/' );
    end if;
  end loop;
end;
$$;
revoke all on function public.send_recruitment_reminders() from public;

create extension if not exists pg_cron with schema cron;

do $$
begin
  if exists(select 1 from cron.job where jobname='talentos-recrutamento-lembretes') then
    perform cron.unschedule(jobid) from cron.job where jobname='talentos-recrutamento-lembretes';
  end if;
end $$;

select cron.schedule('talentos-recrutamento-lembretes','0 11 * * *','select public.send_recruitment_reminders();');
