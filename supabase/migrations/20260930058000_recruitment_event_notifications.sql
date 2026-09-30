-- TalentOS Industrial: event-driven candidate/recruiter notifications
create or replace function public.notify_application_event()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  if tg_op='INSERT' then
    insert into public.notifications(user_id,kind,title,body,href)
    values(new.candidate_id,'candidatura','Candidatura recebida','Sua candidatura foi registrada no processo seletivo.','/');
  elsif new.status is distinct from old.status then
    insert into public.notifications(user_id,kind,title,body,href)
    values(new.candidate_id,'candidatura','Sua candidatura avançou','A etapa da sua candidatura foi atualizada para '||new.status||'.','/');
  end if;
  return new;
end;
$$;
drop trigger if exists application_notification on public.applications;
create trigger application_notification after insert or update of status on public.applications
for each row execute function public.notify_application_event();
revoke all on function public.notify_application_event() from public;

create or replace function public.notify_message_event()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  insert into public.notifications(user_id,kind,title,body,href)
  values(new.recipient_id,'mensagem','Nova mensagem sobre sua candidatura','Você recebeu uma nova mensagem no processo seletivo.','/');
  return new;
end;
$$;
drop trigger if exists message_notification on public.messages;
create trigger message_notification after insert on public.messages
for each row execute function public.notify_message_event();
revoke all on function public.notify_message_event() from public;

create or replace function public.notify_interview_event()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare candidate_id_value uuid; job_title text;
begin
  select a.candidate_id,j.title into candidate_id_value,job_title
  from public.applications a join public.jobs j on j.id=a.job_id
  where a.id=new.application_id;
  if tg_op='INSERT' then
    insert into public.notifications(user_id,kind,title,body,href)
    values(candidate_id_value,'entrevista','Entrevista agendada','Sua entrevista para '||coalesce(job_title,'a vaga')||' foi agendada para '||to_char(new.scheduled_at at time zone 'America/Sao_Paulo','DD/MM/YYYY HH24:MI')||'.','/');
  elsif new.status is distinct from old.status then
    insert into public.notifications(user_id,kind,title,body,href)
    values(candidate_id_value,'entrevista','Entrevista atualizada','O status da sua entrevista para '||coalesce(job_title,'a vaga')||' foi atualizado para '||new.status||'.','/');
  end if;
  return new;
end;
$$;
drop trigger if exists interview_notification on public.interviews;
create trigger interview_notification after insert or update of status on public.interviews
for each row execute function public.notify_interview_event();
revoke all on function public.notify_interview_event() from public;

create or replace function public.notify_offer_event()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare candidate_id_value uuid; job_title text;
begin
  select a.candidate_id,j.title into candidate_id_value,job_title
  from public.applications a join public.jobs j on j.id=a.job_id
  where a.id=new.application_id;
  if tg_op='INSERT' then
    insert into public.notifications(user_id,kind,title,body,href)
    values(candidate_id_value,'proposta','Nova proposta de contratação','Você recebeu uma proposta para '||coalesce(job_title,'a vaga')||'.','/');
  elsif new.status is distinct from old.status then
    if candidate_id_value is not null then
      insert into public.notifications(user_id,kind,title,body,href)
      values(candidate_id_value,'proposta','Proposta atualizada','O status da sua proposta foi atualizado para '||new.status||'.','/');
    end if;
    if old.status='enviada' and new.status in ('aceita','recusada') and new.created_by is not null then
      insert into public.notifications(user_id,kind,title,body,href)
      values(new.created_by,'proposta','Candidato respondeu à proposta','A proposta foi '||new.status||'.','/');
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists offer_notification on public.offers;
create trigger offer_notification after insert or update of status on public.offers
for each row execute function public.notify_offer_event();
revoke all on function public.notify_offer_event() from public;

create or replace function public.notify_interview_response()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  if old.status='agendada' and new.status in ('confirmada','cancelada') and new.interviewer_id is not null then
    insert into public.notifications(user_id,kind,title,body,href)
    values(new.interviewer_id,'entrevista','Candidato respondeu à entrevista','O candidato respondeu '||case when new.status='confirmada' then 'confirmando' else 'cancelando' end||' a entrevista.','/');
  end if;
  return new;
end;
$$;
drop trigger if exists interview_response_notification on public.interviews;
create trigger interview_response_notification after update of status on public.interviews
for each row execute function public.notify_interview_response();
revoke all on function public.notify_interview_response() from public;

revoke execute on function public.notify_application_event() from anon, authenticated, public;
revoke execute on function public.notify_message_event() from anon, authenticated, public;
revoke execute on function public.notify_interview_event() from anon, authenticated, public;
revoke execute on function public.notify_offer_event() from anon, authenticated, public;
revoke execute on function public.notify_interview_response() from anon, authenticated, public;
