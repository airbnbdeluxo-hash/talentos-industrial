-- TalentOS: operational Gap-to-Training
alter table public.training_recommendations
  alter column job_id set not null;

alter table public.training_recommendations
  add column if not exists gap_type text not null default 'nivel' check (gap_type in ('ausente','nivel')),
  add column if not exists current_proficiency smallint,
  add column if not exists target_proficiency smallint not null default 3 check (target_proficiency between 1 and 5),
  add column if not exists started_at timestamptz,
  add column if not exists completed_at timestamptz,
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists outcome_note text;

alter table public.training_recommendations
  drop constraint if exists training_recommendations_status_check;
alter table public.training_recommendations
  add constraint training_recommendations_status_check
  check (status in ('recomendado','em_andamento','concluido','dispensado','resolvido'));

create unique index if not exists uq_training_recommendations_candidate_job_skill
  on public.training_recommendations(candidate_id,job_id,skill_id);
create index if not exists idx_training_candidate_status
  on public.training_recommendations(candidate_id,status,updated_at desc);

create or replace function public.generate_training_plan_for_job(
  p_candidate_id uuid,p_job_id uuid
) returns setof public.training_recommendations
language plpgsql volatile security invoker set search_path=public
as $$
declare
  actor uuid := (select auth.uid());
  req record;
  gap_kind text;
  gap_reason text;
  gap_priority smallint;
  gap_hours numeric(6,1);
begin
  if actor is null then raise exception 'Autenticação obrigatória'; end if;
  if not exists(select 1 from public.jobs j where j.id=p_job_id) then raise exception 'Vaga não encontrada'; end if;

  if actor <> p_candidate_id
     and not exists (
       select 1 from public.jobs j
       join public.company_members cm on cm.company_id=j.company_id
       where j.id=p_job_id and cm.user_id=actor and cm.member_role in ('owner','recruiter')
     )
  then raise exception 'Sem permissão para gerar plano'; end if;

  for req in
    select js.skill_id,s.name skill_name,coalesce(js.min_proficiency,3) target_level,
           cs.proficiency current_level
    from public.job_skills js
    join public.skills s on s.id=js.skill_id
    left join public.candidate_skills cs on cs.candidate_id=p_candidate_id and cs.skill_id=js.skill_id
    where js.job_id=p_job_id
      and coalesce(js.required,true)
      and (cs.skill_id is null or coalesce(cs.proficiency,0) < coalesce(js.min_proficiency,3))
    order by js.weight desc nulls last,js.skill_id
  loop
    if req.current_level is null then
      gap_kind:='ausente';
      gap_reason:='Skill exigida pela vaga ainda não está no Skill Passport.';
      gap_priority:=1;
      gap_hours:=16;
    else
      gap_kind:='nivel';
      gap_reason:=format('Nível declarado %s abaixo do nível %s exigido pela vaga.',req.current_level,req.target_level);
      gap_priority:=2;
      gap_hours:=8;
    end if;

    insert into public.training_recommendations(
      candidate_id,job_id,skill_id,priority,reason,estimated_hours,status,
      gap_type,current_proficiency,target_proficiency,updated_at
    )
    values(
      p_candidate_id,p_job_id,req.skill_id,gap_priority,gap_reason,gap_hours,'recomendado',
      gap_kind,req.current_level,req.target_level,now()
    )
    on conflict(candidate_id,job_id,skill_id)
    do update set
      priority=excluded.priority,reason=excluded.reason,estimated_hours=excluded.estimated_hours,
      gap_type=excluded.gap_type,current_proficiency=excluded.current_proficiency,
      target_proficiency=excluded.target_proficiency,updated_at=now(),
      status=case
        when public.training_recommendations.status in ('dispensado','resolvido') then 'recomendado'
        else public.training_recommendations.status
      end;
  end loop;

  update public.training_recommendations tr
  set status='resolvido',updated_at=now()
  where tr.candidate_id=p_candidate_id and tr.job_id=p_job_id
    and tr.status in ('recomendado','em_andamento')
    and not exists(
      select 1 from public.job_skills js
      left join public.candidate_skills cs on cs.candidate_id=p_candidate_id and cs.skill_id=js.skill_id
      where js.job_id=p_job_id and js.skill_id=tr.skill_id and coalesce(js.required,true)
        and (cs.skill_id is null or coalesce(cs.proficiency,0) < coalesce(js.min_proficiency,3))
    );

  return query
    select * from public.training_recommendations
    where candidate_id=p_candidate_id and job_id=p_job_id
    order by status,priority,created_at;
end;
$$;

create or replace function public.update_training_recommendation(
  p_recommendation_id uuid,p_status text,p_note text default null
) returns public.training_recommendations
language plpgsql volatile security invoker set search_path=public
as $$
declare
  r public.training_recommendations;
  actor uuid := (select auth.uid());
begin
  if actor is null then raise exception 'Autenticação obrigatória'; end if;
  if p_status not in ('em_andamento','concluido','dispensado') then raise exception 'Status inválido'; end if;

  update public.training_recommendations tr
  set status=p_status,
      outcome_note=coalesce(nullif(trim(p_note),''),tr.outcome_note),
      started_at=case when p_status='em_andamento' and tr.started_at is null then now() else tr.started_at end,
      completed_at=case
        when p_status='concluido' then coalesce(tr.completed_at,now())
        when p_status in ('em_andamento','dispensado') then null
        else tr.completed_at
      end,
      updated_at=now()
  where tr.id=p_recommendation_id and tr.candidate_id=actor
  returning tr.* into r;

  if r.id is null then raise exception 'Recomendação não encontrada ou sem permissão'; end if;
  return r;
end;
$$;

revoke all on function public.generate_training_plan_for_job(uuid,uuid) from public;
grant execute on function public.generate_training_plan_for_job(uuid,uuid) to authenticated;
revoke all on function public.update_training_recommendation(uuid,text,text) from public;
grant execute on function public.update_training_recommendation(uuid,text,text) to authenticated;

drop policy if exists "candidate_training_update" on public.training_recommendations;
create policy "candidate_training_update" on public.training_recommendations
for update to authenticated
using(candidate_id=(select auth.uid()))
with check(candidate_id=(select auth.uid()));

drop policy if exists "training_visibility" on public.training_recommendations;
create policy "training_visibility" on public.training_recommendations
for select to authenticated
using(
  candidate_id=(select auth.uid())
  or exists(
    select 1 from public.jobs j
    join public.company_members cm on cm.company_id=j.company_id
    where j.id=training_recommendations.job_id and cm.user_id=(select auth.uid())
  )
);
