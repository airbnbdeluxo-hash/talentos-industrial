-- Harden server-side challenge scoring and clean up linter findings.
create schema if not exists private;

drop policy if exists challenge_answer_keys_deny_all on public.challenge_answer_keys;
create policy challenge_answer_keys_deny_all on public.challenge_answer_keys
for all to authenticated using (false) with check (false);

create index if not exists idx_challenge_attempts_challenge
  on public.challenge_attempts(challenge_id);

create index if not exists idx_challenge_attempts_job
  on public.challenge_attempts(job_id);

create index if not exists idx_skill_assessments_challenge
  on public.skill_assessments(challenge_id);

create or replace function private.get_challenge_answer_key(p_attempt_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public,private
as $$
declare v_answers jsonb;
begin
  if (select auth.uid()) is null then raise exception 'authentication required'; end if;
  select k.answers into v_answers
  from public.challenge_attempts ca
  join public.challenge_answer_keys k on k.challenge_id=ca.challenge_id
  where ca.id=p_attempt_id
    and ca.candidate_id=(select auth.uid())
    and ca.status='em_andamento';
  if v_answers is null then raise exception 'attempt not found'; end if;
  return v_answers;
end;
$$;

revoke all on schema private from public,anon,authenticated;
grant usage on schema private to authenticated;
revoke all on function private.get_challenge_answer_key(uuid) from public,anon;
grant execute on function private.get_challenge_answer_key(uuid) to authenticated;

create or replace function public.complete_challenge(p_attempt_id uuid,p_answers jsonb)
returns table(score numeric(5,2),correct_count integer,total_count integer)
language plpgsql
security invoker
set search_path=public
as $$
declare
 v_challenge uuid;
 v_candidate uuid;
 v_job uuid;
 v_questions jsonb;
 v_answer_key jsonb;
 v_total integer;
 v_correct integer;
 v_score numeric(5,2);
begin
 if (select auth.uid()) is null then raise exception 'authentication required'; end if;

 select ca.challenge_id,ca.candidate_id,ca.job_id,cl.questions
 into v_challenge,v_candidate,v_job,v_questions
 from public.challenge_attempts ca
 join public.challenge_library cl on cl.id=ca.challenge_id
 where ca.id=p_attempt_id
   and ca.candidate_id=(select auth.uid())
   and ca.status='em_andamento';

 if v_candidate is null then raise exception 'attempt not found'; end if;

 v_answer_key=private.get_challenge_answer_key(p_attempt_id);
 select jsonb_array_length(v_questions) into v_total;

 select count(*) into v_correct
 from jsonb_array_elements(v_questions) q
 where coalesce((p_answers ->> (q->>'id'))::int,-1)
       = coalesce((v_answer_key ->> (q->>'id'))::int,-1);

 v_score=round(100.0*v_correct/greatest(v_total,1),2);

 update public.challenge_attempts
 set answers=p_answers,score=v_score,status='concluido',completed_at=now()
 where id=p_attempt_id
   and candidate_id=(select auth.uid())
   and status='em_andamento';

 insert into public.skill_assessments(candidate_id,job_id,challenge_id,attempt_id,assessment_type,score,status,completed_at)
 values((select auth.uid()),v_job,v_challenge,p_attempt_id,'pratica',v_score,'concluido',now());

 insert into public.skill_evidence(candidate_id,skill_id,evidence_type,title,issuer,verified,verified_at,score,notes)
 select (select auth.uid()),cl.skill_id,'desafio',cl.title,'TalentOS Challenge Engine',true,now(),v_score,
        'Avaliação objetiva concluída com pontuação calculada no banco.'
 from public.challenge_library cl where cl.id=v_challenge;

 return query select v_score,v_correct,v_total;
end;
$$;

revoke all on function public.complete_challenge(uuid,jsonb) from public,anon;
grant execute on function public.complete_challenge(uuid,jsonb) to authenticated;