-- Prevent candidates from bypassing the official challenge/evidence flow.
-- Candidates may create only safe pending evidence. Challenge completion opens a
-- transaction-local write gate used by RLS for the attempt and generated assessment.

drop policy if exists challenge_attempts_self_insert on public.challenge_attempts;
create policy challenge_attempts_self_insert
on public.challenge_attempts
for insert
to authenticated
with check (
  private.is_admin()
  or (
    candidate_id = (select auth.uid())
    and status = 'em_andamento'
    and answers = '{}'::jsonb
    and score is null
    and completed_at is null
    and exists (
      select 1
      from public.challenge_library cl
      where cl.id = challenge_attempts.challenge_id
        and cl.active
    )
  )
);

drop policy if exists challenge_attempts_self_update on public.challenge_attempts;
create policy challenge_attempts_self_update
on public.challenge_attempts
for update
to authenticated
using (
  private.is_admin()
  or candidate_id = (select auth.uid())
)
with check (
  private.is_admin()
  or (
    candidate_id = (select auth.uid())
    and (select current_setting('talentos.challenge_complete', true)) = '1'
  )
);

drop policy if exists candidate_assessment_insert on public.skill_assessments;
create policy candidate_assessment_insert
on public.skill_assessments
for insert
to authenticated
with check (
  private.is_admin()
  or (
    candidate_id = (select auth.uid())
    and (select current_setting('talentos.challenge_complete', true)) = '1'
    and assessment_type = 'pratica'
    and score is null
    and status = 'concluido'
    and challenge_id is not null
    and attempt_id is not null
    and completed_at is not null
    and exists (
      select 1
      from public.challenge_attempts ca
      where ca.id = skill_assessments.attempt_id
        and ca.challenge_id = skill_assessments.challenge_id
        and ca.candidate_id = (select auth.uid())
        and ca.status = 'concluido'
    )
  )
);

drop policy if exists evidence_insert on public.skill_evidence;
create policy evidence_insert
on public.skill_evidence
for insert
to authenticated
with check (
  private.is_admin()
  or (
    candidate_id = (select auth.uid())
    and verified = false
    and verified_at is null
    and score is null
    and validation_status = 'pendente'
    and reviewed_by is null
    and reviewed_at is null
    and review_note is null
    and (
      evidence_type <> 'desafio'
      or (select current_setting('talentos.challenge_complete', true)) = '1'
    )
  )
);

create or replace function public.complete_challenge(
  p_attempt_id uuid,
  p_answers jsonb
)
returns table(score numeric, correct_count integer, total_count integer)
language plpgsql
set search_path to 'public'
as $$
declare
  v_challenge uuid;
  v_candidate uuid;
  v_job uuid;
  v_questions jsonb;
  v_total integer;
begin
  if (select auth.uid()) is null then
    raise exception 'authentication required';
  end if;

  select ca.challenge_id,ca.candidate_id,ca.job_id,cl.questions
  into v_challenge,v_candidate,v_job,v_questions
  from public.challenge_attempts ca
  join public.challenge_library cl on cl.id=ca.challenge_id
  where ca.id=p_attempt_id
    and ca.candidate_id=(select auth.uid())
    and ca.status='em_andamento';

  if v_candidate is null then
    raise exception 'attempt not found';
  end if;

  v_total=jsonb_array_length(v_questions);

  perform pg_catalog.set_config('talentos.challenge_complete','1',true);

  update public.challenge_attempts
  set answers=p_answers,status='concluido',completed_at=now()
  where id=p_attempt_id
    and candidate_id=(select auth.uid())
    and status='em_andamento';

  insert into public.skill_assessments(candidate_id,job_id,challenge_id,attempt_id,assessment_type,score,status,completed_at)
  values((select auth.uid()),v_job,v_challenge,p_attempt_id,'pratica',null,'concluido',now());

  insert into public.skill_evidence(candidate_id,skill_id,evidence_type,title,issuer,verified,verified_at,score,notes)
  select (select auth.uid()),cl.skill_id,'desafio',cl.title,'TalentOS Challenge',false,null,null,
         'Avaliação concluída e aguardando validação humana.'
  from public.challenge_library cl
  where cl.id=v_challenge;

  return query select null::numeric(5,2),null::integer,v_total;
end;
$$;
