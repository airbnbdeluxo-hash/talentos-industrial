-- Restrict application status changes to authorized company recruiters.
create or replace function public.update_application_status(p_application_id uuid,p_status text)
returns public.applications
language plpgsql
security invoker
set search_path=public
as $$
declare result_row public.applications;
begin
  if p_status not in ('novo','triagem','entrevista','aprovado','rejeitado','contratado') then
    raise exception 'invalid application status';
  end if;
  update public.applications a
  set status=p_status,updated_at=now()
  where a.id=p_application_id
    and exists(
      select 1 from public.jobs j
      join public.company_members cm on cm.company_id=j.company_id
      where j.id=a.job_id
        and cm.user_id=(select auth.uid())
        and cm.member_role in ('owner','recruiter')
    )
  returning a.* into result_row;
  if result_row.id is null then raise exception 'not authorized for this application'; end if;
  return result_row;
end;
$$;
revoke all on function public.update_application_status(uuid,text) from public;
grant execute on function public.update_application_status(uuid,text) to authenticated;

create index if not exists application_notes_author_idx on public.application_notes(author_id);
create index if not exists interview_scorecards_interviewer_idx on public.interview_scorecards(interviewer_id);
create index if not exists interviews_interviewer_idx on public.interviews(interviewer_id);
create index if not exists job_engagement_candidate_idx on public.job_engagement_events(candidate_id);
create index if not exists messages_recipient_idx on public.messages(recipient_id);
create index if not exists messages_sender_idx on public.messages(sender_id);
create index if not exists offers_created_by_idx on public.offers(created_by);
create index if not exists talent_pools_created_by_idx on public.talent_pools(created_by);
