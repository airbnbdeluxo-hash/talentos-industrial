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


-- Source integrity is enforced in the database for all API callers.
-- System writes stay in a private function with explicit ownership checks.
create or replace function private.record_training_evidence(
 p_recommendation_id uuid,p_evidence_id uuid,p_assessment_id uuid,p_attempt_id uuid,p_completion_type text
) returns public.training_recommendations language plpgsql security definer set search_path='' as $$
declare rec public.training_recommendations; result public.training_recommendations;
begin
 if auth.uid() is null then raise exception 'authentication required'; end if;
 select * into rec from public.training_recommendations where id=p_recommendation_id for update;
 if not found or rec.candidate_id is distinct from auth.uid() then raise exception 'not authorized'; end if;
 if num_nonnulls(p_evidence_id,p_assessment_id,p_attempt_id)<>1 then raise exception 'exactly one evidence source is required'; end if;
 if p_evidence_id is not null then
   if p_completion_type is distinct from 'evidencia' or not exists (
     select 1 from public.skill_evidence e where e.id=p_evidence_id and e.candidate_id=rec.candidate_id and e.skill_id=rec.skill_id
       and e.validation_status<>'reprovada' and (e.expires_at is null or e.expires_at>now())
   ) then raise exception 'Evidência inválida para esta habilidade'; end if;
 elsif p_assessment_id is not null then
   if p_completion_type is distinct from 'avaliacao' or not exists (
     select 1 from public.skill_assessments a join public.challenge_library c on c.id=a.challenge_id
     join public.challenge_attempts ca on ca.id=a.attempt_id and ca.challenge_id=c.id and ca.candidate_id=a.candidate_id
     where a.id=p_assessment_id and a.candidate_id=rec.candidate_id and c.skill_id=rec.skill_id
       and a.status='concluido' and a.completed_at is not null and ca.status='concluido' and ca.completed_at is not null
   ) then raise exception 'Avaliação não concluída ou de outra habilidade'; end if;
 else
   if p_completion_type is distinct from 'desafio' or not exists (
     select 1 from public.challenge_attempts a join public.challenge_library c on c.id=a.challenge_id
     where a.id=p_attempt_id and a.candidate_id=rec.candidate_id and c.skill_id=rec.skill_id
       and a.status='concluido' and a.completed_at is not null
   ) then raise exception 'Desafio não concluído ou de outra habilidade'; end if;
 end if;
 insert into public.training_evidence_links(recommendation_id,evidence_id,assessment_id,attempt_id,completion_type,recorded_by)
 values(rec.id,p_evidence_id,p_assessment_id,p_attempt_id,p_completion_type,auth.uid())
 on conflict(recommendation_id) do update set evidence_id=excluded.evidence_id,assessment_id=excluded.assessment_id,
 attempt_id=excluded.attempt_id,completion_type=excluded.completion_type,recorded_by=excluded.recorded_by,created_at=now();
 perform set_config('talentos.training_candidate_update','1',true);
 update public.training_recommendations set status='concluido',completed_at=now(),updated_at=now(),
 outcome_note='Desenvolvimento concluído com evidência. A evolução da habilidade depende de revisão humana.'
 where id=rec.id returning * into result;
 perform set_config('talentos.training_candidate_update','',true);
 if p_evidence_id is not null then perform private.apply_reviewed_skill_evidence(p_evidence_id); end if;
 insert into public.audit_events(actor_id,action,entity_type,entity_id,metadata)
 values(auth.uid(),'training_evidence_recorded','training_recommendations',rec.id,
 jsonb_build_object('evidence_id',p_evidence_id,'assessment_id',p_assessment_id,'attempt_id',p_attempt_id,'skill_id',rec.skill_id));
 return result;
end $$;
revoke all on function private.record_training_evidence(uuid,uuid,uuid,uuid,text) from public,anon;
grant execute on function private.record_training_evidence(uuid,uuid,uuid,uuid,text) to authenticated;
create or replace function public.record_training_evidence(
 p_recommendation_id uuid,p_evidence_id uuid default null,p_assessment_id uuid default null,p_attempt_id uuid default null,
 p_completion_type text default 'evidencia'
) returns public.training_recommendations language sql security invoker set search_path='' as $$
 select private.record_training_evidence(p_recommendation_id,p_evidence_id,p_assessment_id,p_attempt_id,p_completion_type);
$$;
revoke all on function public.record_training_evidence(uuid,uuid,uuid,uuid,text) from public,anon;
grant execute on function public.record_training_evidence(uuid,uuid,uuid,uuid,text) to authenticated;
revoke all on public.training_evidence_links from public,anon,authenticated;
grant select on public.training_evidence_links to authenticated;
create index if not exists training_evidence_links_evidence_idx on public.training_evidence_links(evidence_id) where evidence_id is not null;
create index if not exists training_evidence_links_assessment_idx on public.training_evidence_links(assessment_id) where assessment_id is not null;
create index if not exists training_evidence_links_attempt_idx on public.training_evidence_links(attempt_id) where attempt_id is not null;
