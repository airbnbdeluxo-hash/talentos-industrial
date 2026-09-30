create table if not exists public.training_evidence_links (
  recommendation_id uuid primary key references public.training_recommendations(id) on delete cascade,
  evidence_id uuid references public.skill_evidence(id) on delete set null,
  assessment_id uuid references public.skill_assessments(id) on delete set null,
  attempt_id uuid references public.challenge_attempts(id) on delete set null,
  completion_type text not null check (completion_type in ('evidencia','avaliacao','desafio','manual')),
  recorded_by uuid not null,
  created_at timestamptz not null default now(),
  check (num_nonnulls(evidence_id,assessment_id,attempt_id)=1)
);

alter table public.training_evidence_links enable row level security;
grant select on public.training_evidence_links to authenticated;

drop policy if exists training_evidence_links_select on public.training_evidence_links;
create policy training_evidence_links_select on public.training_evidence_links
for select to authenticated using (
  exists (select 1 from public.training_recommendations tr where tr.id=recommendation_id and tr.candidate_id=(select auth.uid()))
  or exists (
    select 1 from public.training_recommendations tr
    join public.jobs j on j.id=tr.job_id
    join public.company_members cm on cm.company_id=j.company_id
    where tr.id=recommendation_id and cm.user_id=(select auth.uid())
  )
);

create or replace function public.record_training_evidence(
 p_recommendation_id uuid,p_evidence_id uuid default null,p_assessment_id uuid default null,
 p_attempt_id uuid default null,p_completion_type text default 'evidencia'
) returns public.training_recommendations
language plpgsql security invoker set search_path=public
as $$
declare rec public.training_recommendations%rowtype; out_rec public.training_recommendations%rowtype;
begin
 select * into rec from public.training_recommendations where id=p_recommendation_id;
 if not found or rec.candidate_id <> (select auth.uid()) then raise exception 'not authorized'; end if;
 if num_nonnulls(p_evidence_id,p_assessment_id,p_attempt_id)<>1 then raise exception 'exactly one evidence source is required'; end if;
 if p_completion_type not in ('evidencia','avaliacao','desafio','manual') then raise exception 'invalid completion type'; end if;
 if p_evidence_id is not null and not exists(select 1 from public.skill_evidence e where e.id=p_evidence_id and e.candidate_id=rec.candidate_id and e.skill_id=rec.skill_id) then raise exception 'evidence does not match candidate skill'; end if;
 if p_assessment_id is not null and not exists(select 1 from public.skill_assessments a where a.id=p_assessment_id and a.candidate_id=rec.candidate_id) then raise exception 'assessment does not belong to candidate'; end if;
 if p_attempt_id is not null and not exists(select 1 from public.challenge_attempts a where a.id=p_attempt_id and a.candidate_id=rec.candidate_id and a.status='concluido') then raise exception 'challenge attempt is not completed'; end if;
 insert into public.training_evidence_links(recommendation_id,evidence_id,assessment_id,attempt_id,completion_type,recorded_by)
 values(p_recommendation_id,p_evidence_id,p_assessment_id,p_attempt_id,p_completion_type,(select auth.uid()))
 on conflict(recommendation_id) do update set evidence_id=excluded.evidence_id,assessment_id=excluded.assessment_id,attempt_id=excluded.attempt_id,completion_type=excluded.completion_type,recorded_by=(select auth.uid()),created_at=now();
 update public.training_recommendations
 set status='concluido',completed_at=now(),updated_at=now(),
     outcome_note=coalesce(outcome_note,'Evidência de desenvolvimento registrada.')
 where id=p_recommendation_id returning * into out_rec;
 return out_rec;
end $$;

grant execute on function public.record_training_evidence(uuid,uuid,uuid,uuid,text) to authenticated;
revoke execute on function public.record_training_evidence(uuid,uuid,uuid,uuid,text) from anon,public;
create index if not exists training_evidence_links_evidence_idx on public.training_evidence_links(evidence_id) where evidence_id is not null;
create index if not exists training_evidence_links_assessment_idx on public.training_evidence_links(assessment_id) where assessment_id is not null;
create index if not exists training_evidence_links_attempt_idx on public.training_evidence_links(attempt_id) where attempt_id is not null;
