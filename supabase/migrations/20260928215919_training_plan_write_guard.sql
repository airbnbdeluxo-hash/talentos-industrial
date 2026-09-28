-- TalentOS: keep training plan generation security-invoker with guarded writes
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
  if not exists(select 1 from public.candidate_profiles cp where cp.profile_id=p_candidate_id) then
    raise exception 'Candidato não encontrado';
  end if;
  if not exists(select 1 from public.jobs j where j.id=p_job_id) then raise exception 'Vaga não encontrada'; end if;

  if actor <> p_candidate_id
     and not exists (
       select 1 from public.jobs j
       join public.company_members cm on cm.company_id=j.company_id
       where j.id=p_job_id and cm.user_id=actor and cm.member_role in ('owner','recruiter')
     )
  then raise exception 'Sem permissão para gerar plano'; end if;

  perform set_config('talentos.training_generation','1',true);

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

revoke all on function public.generate_training_plan_for_job(uuid,uuid) from public;
grant execute on function public.generate_training_plan_for_job(uuid,uuid) to authenticated;
revoke execute on function public.generate_training_plan_for_job(uuid,uuid) from anon;

drop policy if exists training_generation_insert on public.training_recommendations;
create policy training_generation_insert on public.training_recommendations
for insert to authenticated
with check(
  candidate_id=(select auth.uid())
  or exists(
    select 1
    from public.jobs j
    join public.company_members cm on cm.company_id=j.company_id
    where j.id=training_recommendations.job_id
      and cm.user_id=(select auth.uid())
      and cm.member_role in ('owner','recruiter')
  )
);

create or replace function public.guard_training_recommendation_insert()
returns trigger
language plpgsql
security invoker
set search_path=public
as $$
begin
  if (select current_setting('talentos.training_generation',true)) <> '1' then
    raise exception 'Criação direta de plano de treinamento não permitida';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_training_recommendation_insert on public.training_recommendations;
create trigger trg_guard_training_recommendation_insert
before insert on public.training_recommendations
for each row execute function public.guard_training_recommendation_insert();

revoke all on function public.guard_training_recommendation_insert() from public;
grant execute on function public.guard_training_recommendation_insert() to authenticated;