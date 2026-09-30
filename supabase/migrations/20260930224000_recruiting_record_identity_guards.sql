-- Protect the identity/ownership fields of core recruiting records.
-- RLS decides which rows a caller can update; these triggers also prevent an
-- authorized updater from moving a row to another candidate/job/application.

create or replace function private.enforce_recruiting_record_identity()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_table_name = 'applications' then
    if new.id is distinct from old.id
       or new.candidate_id is distinct from old.candidate_id
       or new.job_id is distinct from old.job_id
       or new.created_at is distinct from old.created_at then
      raise exception 'application identity is immutable';
    end if;
  elsif tg_table_name = 'interviews' then
    if new.id is distinct from old.id
       or new.application_id is distinct from old.application_id
       or new.interviewer_id is distinct from old.interviewer_id
       or new.created_at is distinct from old.created_at then
      raise exception 'interview identity is immutable';
    end if;
  elsif tg_table_name = 'interview_scorecards' then
    if new.id is distinct from old.id
       or new.application_id is distinct from old.application_id
       or new.interviewer_id is distinct from old.interviewer_id
       or new.competency is distinct from old.competency
       or new.created_at is distinct from old.created_at then
      raise exception 'scorecard identity is immutable';
    end if;
  elsif tg_table_name = 'offers' then
    if new.id is distinct from old.id
       or new.application_id is distinct from old.application_id
       or new.created_by is distinct from old.created_by
       or new.created_at is distinct from old.created_at then
      raise exception 'offer identity is immutable';
    end if;
  elsif tg_table_name = 'messages' then
    if new.id is distinct from old.id
       or new.application_id is distinct from old.application_id
       or new.sender_id is distinct from old.sender_id
       or new.recipient_id is distinct from old.recipient_id
       or new.body is distinct from old.body
       or new.created_at is distinct from old.created_at then
      raise exception 'message identity and content are immutable';
    end if;
  end if;

  return new;
end;
$$;

revoke all on function private.enforce_recruiting_record_identity() from public, anon, authenticated;

drop trigger if exists applications_identity_guard on public.applications;
create trigger applications_identity_guard
before update on public.applications
for each row execute function private.enforce_recruiting_record_identity();

drop trigger if exists interviews_identity_guard on public.interviews;
create trigger interviews_identity_guard
before update on public.interviews
for each row execute function private.enforce_recruiting_record_identity();

drop trigger if exists interview_scorecards_identity_guard on public.interview_scorecards;
create trigger interview_scorecards_identity_guard
before update on public.interview_scorecards
for each row execute function private.enforce_recruiting_record_identity();

drop trigger if exists offers_identity_guard on public.offers;
create trigger offers_identity_guard
before update on public.offers
for each row execute function private.enforce_recruiting_record_identity();

drop trigger if exists messages_identity_guard on public.messages;
create trigger messages_identity_guard
before update on public.messages
for each row execute function private.enforce_recruiting_record_identity();
