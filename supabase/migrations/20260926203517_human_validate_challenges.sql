-- Final alignment for the human-validated challenge workflow.
drop function if exists private.get_challenge_answer_key(uuid);
drop table if exists public.challenge_answer_keys;
drop schema if exists private;

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
 v_total integer;
begin
 if (select auth.uid()) is null then raise exception 'authentication required'; end if;
 select ca.challenge_id,ca.candidate_id,ca.job_id,cl.questions
 into v_challenge,v_candidate,v_job,v_questions
 from public.challenge_attempts ca
 join public.challenge_library cl on cl.id=ca.challenge_id
 where ca.id=p_attempt_id and ca.candidate_id=(select auth.uid()) and ca.status='em_andamento';
 if v_candidate is null then raise exception 'attempt not found'; end if;
 v_total=jsonb_array_length(v_questions);
 update public.challenge_attempts
 set answers=p_answers,status='concluido',completed_at=now()
 where id=p_attempt_id and candidate_id=(select auth.uid()) and status='em_andamento';
 insert into public.skill_assessments(candidate_id,job_id,challenge_id,attempt_id,assessment_type,score,status,completed_at)
 values((select auth.uid()),v_job,v_challenge,p_attempt_id,'pratica',null,'concluido',now());
 insert into public.skill_evidence(candidate_id,skill_id,evidence_type,title,issuer,verified,verified_at,score,notes)
 select (select auth.uid()),cl.skill_id,'desafio',cl.title,'TalentOS Challenge',false,null,null,
        'Avaliação concluída e aguardando validação humana.'
 from public.challenge_library cl where cl.id=v_challenge;
 return query select null::numeric(5,2),null::integer,v_total;
end;
$$;
revoke all on function public.complete_challenge(uuid,jsonb) from public,anon;
grant execute on function public.complete_challenge(uuid,jsonb) to authenticated;