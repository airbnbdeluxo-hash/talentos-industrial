-- Secure challenge library and server-side answer keys.
create table if not exists public.challenge_answer_keys(
  challenge_id uuid primary key references public.challenge_library(id) on delete cascade,
  answers jsonb not null,
  created_at timestamptz not null default now()
);

alter table public.challenge_answer_keys enable row level security;

insert into public.challenge_answer_keys(challenge_id,answers)
select id,
       coalesce((select jsonb_object_agg(q->>'id',q->'answer') from jsonb_array_elements(questions) q),'{}'::jsonb)
from public.challenge_library
on conflict (challenge_id) do update set answers=excluded.answers;

update public.challenge_library
set questions=coalesce((select jsonb_agg(q - 'answer') from jsonb_array_elements(questions) q),'[]'::jsonb);

revoke all on public.challenge_answer_keys from anon,authenticated;
revoke all on function public.complete_challenge(uuid,jsonb) from public,anon;

create or replace function public.complete_challenge(p_attempt_id uuid,p_answers jsonb)
returns table(score numeric(5,2),correct_count integer,total_count integer)
language plpgsql
security definer
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

  select ca.challenge_id,ca.candidate_id,ca.job_id,cl.questions,k.answers
  into v_challenge,v_candidate,v_job,v_questions,v_answer_key
  from public.challenge_attempts ca
  join public.challenge_library cl on cl.id=ca.challenge_id
  join public.challenge_answer_keys k on k.challenge_id=ca.challenge_id
  where ca.id=p_attempt_id
    and ca.candidate_id=(select auth.uid())
    and ca.status='em_andamento';

  if v_candidate is null then raise exception 'attempt not found'; end if;

  select jsonb_array_length(v_questions) into v_total;
  select count(*) into v_correct
  from jsonb_array_elements(v_questions) q
  where coalesce((p_answers ->> (q->>'id'))::int,-1)
        = coalesce((v_answer_key ->> (q->>'id'))::int,-1);

  v_score=round(100.0*v_correct/greatest(v_total,1),2);

  update public.challenge_attempts
  set answers=p_answers,score=v_score,status='concluido',completed_at=now()
  where id=p_attempt_id;

  insert into public.skill_assessments(candidate_id,job_id,challenge_id,attempt_id,assessment_type,score,status,completed_at)
  values((select auth.uid()),v_job,v_challenge,p_attempt_id,'pratica',v_score,'concluido',now());

  insert into public.skill_evidence(candidate_id,skill_id,evidence_type,title,issuer,verified,verified_at,score,notes)
  select (select auth.uid()),cl.skill_id,'desafio',cl.title,'TalentOS Challenge Engine',true,now(),v_score,
         'Avaliação objetiva concluída com pontuação calculada no banco.'
  from public.challenge_library cl
  where cl.id=v_challenge;

  return query select v_score,v_correct,v_total;
end;
$$;

revoke all on function public.complete_challenge(uuid,jsonb) from public,anon;
grant execute on function public.complete_challenge(uuid,jsonb) to authenticated;