create index if not exists candidate_skill_events_skill_idx
  on public.candidate_skill_events(skill_id);
create index if not exists candidate_skill_events_actor_idx
  on public.candidate_skill_events(actor_id);

create table public.candidate_skill_outcome_events (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.candidate_profiles(profile_id) on delete cascade,
  skill_id uuid not null references public.skills(id) on delete cascade,
  outcome_id uuid not null references public.employment_outcomes(id) on delete cascade,
  outcome_signal_id uuid not null unique references public.employment_outcome_skill_signals(id) on delete restrict,
  previous_proficiency smallint not null check (previous_proficiency between 0 and 5),
  new_proficiency smallint not null check (new_proficiency between 1 and 5),
  confidence numeric not null check (confidence between 0 and 1),
  checkpoint text not null check (checkpoint in ('30d','60d','90d','saida')),
  signal_status text not null check (signal_status in ('utilizada','necessita_desenvolvimento','nao_observado','nao_aplicavel')),
  manager_rating smallint check (manager_rating between 1 and 5),
  performance_score numeric check (performance_score between 0 and 100),
  policy_version text not null default 'employment-outcome-v1',
  explanation text not null,
  actor_id uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

alter table public.candidate_skill_outcome_events enable row level security;
revoke all on public.candidate_skill_outcome_events from public, anon, authenticated;
grant select on public.candidate_skill_outcome_events to authenticated;

create policy candidate_skill_outcome_events_read
on public.candidate_skill_outcome_events
for select to authenticated
using (
  candidate_id = (select auth.uid())
  or (select private.is_admin())
  or exists (
    select 1
    from public.employment_outcomes eo
    join public.company_members cm on cm.company_id = eo.company_id
    where eo.id = candidate_skill_outcome_events.outcome_id
      and cm.user_id = (select auth.uid())
      and cm.member_role in ('owner','recruiter','viewer')
  )
);

create index candidate_skill_outcome_events_candidate_skill_idx
  on public.candidate_skill_outcome_events(candidate_id, skill_id, created_at desc);
create index candidate_skill_outcome_events_skill_idx
  on public.candidate_skill_outcome_events(skill_id);
create index candidate_skill_outcome_events_outcome_idx
  on public.candidate_skill_outcome_events(outcome_id);
create index candidate_skill_outcome_events_actor_idx
  on public.candidate_skill_outcome_events(actor_id);

create or replace function private.apply_employment_outcome_skill_signal(p_signal_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  s public.employment_outcome_skill_signals;
  eo public.employment_outcomes;
  cs public.candidate_skills;
  v_before smallint := 0;
  v_level smallint;
  v_cap smallint;
  v_confidence numeric;
  v_required smallint := 1;
  v_training boolean := false;
  v_applied boolean := false;
  v_status text := 'sem_evolucao';
  v_event uuid;
  v_job uuid;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  select * into s
  from public.employment_outcome_skill_signals
  where id = p_signal_id
  for update;

  if not found then
    raise exception 'Sinal de competência não encontrado';
  end if;

  select * into eo
  from public.employment_outcomes
  where id = s.outcome_id
  for update;

  if not found then
    raise exception 'Outcome não encontrado';
  end if;

  if not coalesce(private.is_admin(), false)
     and not exists (
       select 1
       from public.company_members cm
       where cm.company_id = eo.company_id
         and cm.user_id = auth.uid()
         and cm.member_role in ('owner','recruiter')
     )
  then
    raise exception 'Sem permissão para aplicar sinal pós-contratação';
  end if;

  if not exists (
    select 1 from public.job_skills js
    where js.job_id = eo.job_id and js.skill_id = s.skill_id
  ) then
    raise exception 'Skill não pertence aos requisitos da vaga';
  end if;

  perform 1
  from public.candidate_profiles cp
  where cp.profile_id = eo.candidate_id
  for update;

  select * into cs
  from public.candidate_skills
  where candidate_id = eo.candidate_id and skill_id = s.skill_id
  for update;

  v_before := coalesce(cs.proficiency, 0);

  select greatest(1, least(5, js.min_proficiency))
  into v_required
  from public.job_skills js
  where js.job_id = eo.job_id and js.skill_id = s.skill_id
  order by js.required desc, js.weight desc nulls last
  limit 1;

  v_training := s.training_needed or s.signal_status = 'necessita_desenvolvimento';

  if v_training then
    perform set_config('talentos.training_generation','1',true);

    insert into public.training_recommendations(
      candidate_id, job_id, skill_id, priority, reason, status,
      gap_type, current_proficiency, target_proficiency,
      outcome_note, graph_context, updated_at
    )
    values (
      eo.candidate_id,
      eo.job_id,
      s.skill_id,
      case when s.training_needed then 5 else 4 end,
      'Sinal pós-contratação: a competência precisa de desenvolvimento adicional.',
      'recomendado',
      case when v_before = 0 then 'ausente' else 'nivel' end,
      case when v_before = 0 then null else v_before end,
      least(5, greatest(v_required, v_before + 1)),
      left(
        'Outcome ' || eo.checkpoint ||
        coalesce(' · avaliação do gestor ' || s.manager_rating::text || '/5','') ||
        coalesce(' · ' || s.note,''),
        1000
      ),
      jsonb_build_object(
        'source','employment_outcome',
        'outcome_id',eo.id,
        'outcome_signal_id',s.id,
        'capability_node_id',s.capability_node_id,
        'checkpoint',eo.checkpoint
      ),
      now()
    )
    on conflict(candidate_id, job_id, skill_id) do update set
      priority = greatest(public.training_recommendations.priority, excluded.priority),
      reason = excluded.reason,
      current_proficiency = excluded.current_proficiency,
      target_proficiency = greatest(public.training_recommendations.target_proficiency, excluded.target_proficiency),
      status = case
        when public.training_recommendations.status in ('concluido','dispensado','resolvido') then 'recomendado'
        else public.training_recommendations.status
      end,
      completed_at = case
        when public.training_recommendations.status in ('concluido','dispensado','resolvido') then null
        else public.training_recommendations.completed_at
      end,
      outcome_note = excluded.outcome_note,
      graph_context = coalesce(public.training_recommendations.graph_context,'{}'::jsonb) || excluded.graph_context,
      updated_at = now();

    perform set_config('talentos.training_generation','',true);

    insert into public.audit_events(actor_id, action, entity_type, entity_id, metadata)
    values (
      auth.uid(),
      'outcome_training_recommended',
      'employment_outcome_skill_signals',
      s.id,
      jsonb_build_object(
        'candidate_id', eo.candidate_id,
        'job_id', eo.job_id,
        'skill_id', s.skill_id,
        'checkpoint', eo.checkpoint
      )
    );
  end if;

  if s.signal_status = 'utilizada'
     and coalesce(s.manager_rating,0) >= 4
     and coalesce(eo.performance_score,0) >= 70
  then
    if exists (
      select 1 from public.candidate_skill_outcome_events e
      where e.outcome_signal_id = s.id
    ) then
      v_status := 'ja_aplicado';
    else
      v_cap := case eo.checkpoint
        when '30d' then 2
        when '60d' then 3
        when '90d' then 4
        when 'saida' then 4
        else 2
      end;

      v_confidence := case eo.checkpoint
        when '30d' then 0.65
        when '60d' then 0.75
        when '90d' then 0.85
        when 'saida' then 0.80
        else 0.65
      end;

      v_level := greatest(v_before, least(v_before + 1, v_cap));
      if v_level = 0 then v_level := 1; end if;

      insert into public.candidate_skills(
        candidate_id, skill_id, proficiency, verified,
        source_type, source_confidence, source_excerpt
      )
      values (
        eo.candidate_id,
        s.skill_id,
        v_level,
        false,
        'outcome',
        v_confidence,
        left(
          'Outcome ' || eo.checkpoint ||
          ': competência utilizada · gestor ' || s.manager_rating::text || '/5' ||
          ' · performance ' || eo.performance_score::text || '/100' ||
          coalesce(' · ' || s.note,''),
          500
        )
      )
      on conflict(candidate_id, skill_id) do update set
        proficiency = greatest(public.candidate_skills.proficiency, excluded.proficiency),
        source_type = case
          when coalesce(public.candidate_skills.source_confidence,0) > v_confidence
            then public.candidate_skills.source_type
          else excluded.source_type
        end,
        source_confidence = greatest(coalesce(public.candidate_skills.source_confidence,0), v_confidence),
        source_excerpt = case
          when coalesce(public.candidate_skills.source_confidence,0) > v_confidence
            then public.candidate_skills.source_excerpt
          else excluded.source_excerpt
        end;

      insert into public.candidate_skill_outcome_events(
        candidate_id, skill_id, outcome_id, outcome_signal_id,
        previous_proficiency, new_proficiency, confidence,
        checkpoint, signal_status, manager_rating, performance_score,
        explanation, actor_id
      )
      values (
        eo.candidate_id,
        s.skill_id,
        eo.id,
        s.id,
        v_before,
        v_level,
        v_confidence,
        eo.checkpoint,
        s.signal_status,
        s.manager_rating,
        eo.performance_score,
        'Resultado pós-contratação positivo; avanço máximo de um nível por checkpoint, limite por maturidade do acompanhamento. Sem regressão e sem auto-verificação.',
        auth.uid()
      )
      returning id into v_event;

      insert into public.audit_events(actor_id, action, entity_type, entity_id, metadata)
      values (
        auth.uid(),
        'outcome_skill_applied',
        'candidate_skill_outcome_events',
        v_event,
        jsonb_build_object(
          'candidate_id', eo.candidate_id,
          'job_id', eo.job_id,
          'skill_id', s.skill_id,
          'outcome_id', eo.id,
          'outcome_signal_id', s.id,
          'before', v_before,
          'after', v_level,
          'policy', 'employment-outcome-v1'
        )
      );

      for v_job in
        select distinct j.id
        from public.jobs j
        join public.job_skills js on js.job_id = j.id
        where j.status = 'aberta'
          and js.skill_id = s.skill_id
      loop
        perform private.refresh_candidate_job(eo.candidate_id, v_job);
      end loop;

      v_status := 'aplicado';
      v_applied := true;
    end if;
  end if;

  return jsonb_build_object(
    'status', v_status,
    'skill_applied', v_applied,
    'training_recommended', v_training,
    'previous_proficiency', v_before,
    'proficiency', coalesce(v_level, v_before)
  );
end;
$$;

revoke all on function private.apply_employment_outcome_skill_signal(uuid) from public, anon;
grant execute on function private.apply_employment_outcome_skill_signal(uuid) to authenticated;

create or replace function public.save_employment_outcome_skill_signal(
  p_outcome_id uuid,
  p_skill_id uuid,
  p_signal_status text,
  p_manager_rating smallint default null,
  p_training_needed boolean default false,
  p_note text default null
)
returns public.employment_outcome_skill_signals
language plpgsql
security invoker
set search_path=''
as $$
declare
  eo public.employment_outcomes;
  target_node uuid;
  result public.employment_outcome_skill_signals;
begin
  if auth.uid() is null then raise exception 'Autenticação necessária'; end if;
  if p_signal_status not in ('utilizada','necessita_desenvolvimento','nao_observado','nao_aplicavel') then
    raise exception 'Status de skill inválido';
  end if;
  if p_manager_rating is not null and (p_manager_rating < 1 or p_manager_rating > 5) then
    raise exception 'Avaliação deve estar entre 1 e 5';
  end if;

  select * into eo from public.employment_outcomes where id=p_outcome_id;
  if not found then raise exception 'Outcome não encontrado'; end if;

  if not exists (
    select 1 from public.company_members cm
    where cm.company_id=eo.company_id
      and cm.user_id=auth.uid()
      and cm.member_role in ('owner','recruiter')
  ) and not private.is_admin() then
    raise exception 'Sem permissão para registrar sinal de competência';
  end if;

  if not exists (
    select 1
    from public.job_skills js
    join public.applications a on a.job_id=js.job_id
    where a.id=eo.application_id and js.skill_id=p_skill_id
  ) then
    raise exception 'Skill não pertence aos requisitos da vaga';
  end if;

  select cn.id into target_node
  from public.capability_nodes cn
  where cn.skill_id=p_skill_id
    and cn.node_type='competencia'
    and cn.active
  order by cn.created_at
  limit 1;

  perform set_config('talentos.outcome_skill_write','1',true);

  insert into public.employment_outcome_skill_signals(
    outcome_id,skill_id,capability_node_id,signal_status,manager_rating,
    training_needed,note,created_by,updated_at
  )
  values(
    eo.id,p_skill_id,target_node,p_signal_status,p_manager_rating,
    coalesce(p_training_needed,false),p_note,auth.uid(),now()
  )
  on conflict(outcome_id,skill_id) do update set
    capability_node_id=excluded.capability_node_id,
    signal_status=excluded.signal_status,
    manager_rating=excluded.manager_rating,
    training_needed=excluded.training_needed,
    note=excluded.note,
    created_by=auth.uid(),
    updated_at=now()
  returning * into result;

  perform set_config('talentos.outcome_skill_write','',true);
  perform private.apply_employment_outcome_skill_signal(result.id);

  return result;
end;
$$;

revoke all on function public.save_employment_outcome_skill_signal(uuid,uuid,text,smallint,boolean,text) from public, anon;
grant execute on function public.save_employment_outcome_skill_signal(uuid,uuid,text,smallint,boolean,text) to authenticated;

create or replace function public.record_employment_outcome(
  p_application_id uuid,
  p_checkpoint text,
  p_performance_score numeric default null,
  p_ramp_up_days smallint default null,
  p_retention_status text default 'ativo',
  p_skill_feedback jsonb default '{}'::jsonb,
  p_manager_note text default null
)
returns public.employment_outcomes
language plpgsql
security invoker
set search_path=''
as $$
declare
  app public.applications;
  v_company_id uuid;
  result public.employment_outcomes;
  v_signal uuid;
begin
  if auth.uid() is null then raise exception 'Autenticação necessária'; end if;
  if p_checkpoint not in ('30d','60d','90d','saida') then raise exception 'Checkpoint inválido'; end if;
  if p_performance_score is not null and (p_performance_score < 0 or p_performance_score > 100) then
    raise exception 'Performance deve estar entre 0 e 100';
  end if;
  if p_ramp_up_days is not null and p_ramp_up_days < 0 then
    raise exception 'Ramp-up não pode ser negativo';
  end if;
  if p_retention_status not in ('ativo','desligado','promovido','transferido') then
    raise exception 'Status de retenção inválido';
  end if;

  select a.* into app from public.applications a where a.id=p_application_id;
  if not found then raise exception 'Candidatura não encontrada'; end if;
  if app.status <> 'contratado' then raise exception 'Outcome só pode ser registrado após contratação'; end if;

  select j.company_id into v_company_id from public.jobs j where j.id=app.job_id;
  if v_company_id is null then raise exception 'Empresa da vaga não encontrada'; end if;

  if not exists (
    select 1 from public.company_members cm
    where cm.company_id=v_company_id
      and cm.user_id=auth.uid()
      and cm.member_role in ('owner','recruiter')
  ) and not private.is_admin() then
    raise exception 'Sem permissão para registrar outcome';
  end if;

  perform set_config('talentos.outcome_write','1',true);

  insert into public.employment_outcomes(
    application_id,candidate_id,job_id,company_id,checkpoint,performance_score,ramp_up_days,
    retention_status,skill_feedback,manager_note,created_by,updated_at
  )
  values(
    app.id,app.candidate_id,app.job_id,v_company_id,p_checkpoint,p_performance_score,p_ramp_up_days,
    p_retention_status,coalesce(p_skill_feedback,'{}'::jsonb),p_manager_note,auth.uid(),now()
  )
  on conflict(application_id,checkpoint) do update set
    performance_score=excluded.performance_score,
    ramp_up_days=excluded.ramp_up_days,
    retention_status=excluded.retention_status,
    skill_feedback=excluded.skill_feedback,
    manager_note=excluded.manager_note,
    updated_at=now(),
    created_by=auth.uid()
  returning * into result;

  perform set_config('talentos.outcome_write','',true);

  for v_signal in
    select oss.id
    from public.employment_outcome_skill_signals oss
    where oss.outcome_id = result.id
  loop
    perform private.apply_employment_outcome_skill_signal(v_signal);
  end loop;

  return result;
end;
$$;

revoke all on function public.record_employment_outcome(uuid,text,numeric,smallint,text,jsonb,text) from public, anon;
grant execute on function public.record_employment_outcome(uuid,text,numeric,smallint,text,jsonb,text) to authenticated;
