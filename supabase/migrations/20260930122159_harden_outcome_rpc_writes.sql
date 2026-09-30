create or replace function private.record_employment_outcome(
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
security definer
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
  ) and not coalesce(private.is_admin(),false) then
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

revoke all on function private.record_employment_outcome(uuid,text,numeric,smallint,text,jsonb,text) from public, anon;
grant execute on function private.record_employment_outcome(uuid,text,numeric,smallint,text,jsonb,text) to authenticated;

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
language sql
security invoker
set search_path=''
as $$
  select private.record_employment_outcome(
    p_application_id,p_checkpoint,p_performance_score,p_ramp_up_days,
    p_retention_status,p_skill_feedback,p_manager_note
  );
$$;

revoke all on function public.record_employment_outcome(uuid,text,numeric,smallint,text,jsonb,text) from public, anon;
grant execute on function public.record_employment_outcome(uuid,text,numeric,smallint,text,jsonb,text) to authenticated;

create or replace function private.save_employment_outcome_skill_signal(
  p_outcome_id uuid,
  p_skill_id uuid,
  p_signal_status text,
  p_manager_rating smallint default null,
  p_training_needed boolean default false,
  p_note text default null
)
returns public.employment_outcome_skill_signals
language plpgsql
security definer
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
  ) and not coalesce(private.is_admin(),false) then
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

revoke all on function private.save_employment_outcome_skill_signal(uuid,uuid,text,smallint,boolean,text) from public, anon;
grant execute on function private.save_employment_outcome_skill_signal(uuid,uuid,text,smallint,boolean,text) to authenticated;

create or replace function public.save_employment_outcome_skill_signal(
  p_outcome_id uuid,
  p_skill_id uuid,
  p_signal_status text,
  p_manager_rating smallint default null,
  p_training_needed boolean default false,
  p_note text default null
)
returns public.employment_outcome_skill_signals
language sql
security invoker
set search_path=''
as $$
  select private.save_employment_outcome_skill_signal(
    p_outcome_id,p_skill_id,p_signal_status,p_manager_rating,p_training_needed,p_note
  );
$$;

revoke all on function public.save_employment_outcome_skill_signal(uuid,uuid,text,smallint,boolean,text) from public, anon;
grant execute on function public.save_employment_outcome_skill_signal(uuid,uuid,text,smallint,boolean,text) to authenticated;
