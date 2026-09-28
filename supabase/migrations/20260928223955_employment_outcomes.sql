create table public.employment_outcomes (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.applications(id) on delete cascade,
  candidate_id uuid not null references public.candidate_profiles(profile_id) on delete cascade,
  job_id uuid not null references public.jobs(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  checkpoint text not null check (checkpoint in ('30d','60d','90d','saida')),
  performance_score numeric(5,2) check (performance_score is null or (performance_score >= 0 and performance_score <= 100)),
  ramp_up_days smallint check (ramp_up_days is null or ramp_up_days >= 0),
  retention_status text not null default 'ativo'
    check (retention_status in ('ativo','desligado','promovido','transferido')),
  skill_feedback jsonb not null default '{}'::jsonb,
  manager_note text,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (application_id, checkpoint)
);

create index employment_outcomes_company_checkpoint_idx on public.employment_outcomes(company_id, checkpoint, created_at desc);
create index employment_outcomes_candidate_created_idx on public.employment_outcomes(candidate_id, created_at desc);
create index employment_outcomes_job_idx on public.employment_outcomes(job_id, created_at desc);

alter table public.employment_outcomes enable row level security;
revoke all on public.employment_outcomes from anon, authenticated;
grant select on public.employment_outcomes to authenticated;

create policy employment_outcomes_visibility on public.employment_outcomes
for select to authenticated using (
  exists (select 1 from public.company_members cm
          where cm.company_id=employment_outcomes.company_id
            and cm.user_id=(select auth.uid())
            and cm.member_role in ('owner','recruiter','viewer'))
);

create policy employment_outcomes_insert on public.employment_outcomes
for insert to authenticated with check (
  current_setting('talentos.outcome_write', true)='1'
  and exists (select 1 from public.company_members cm
              where cm.company_id=employment_outcomes.company_id
                and cm.user_id=(select auth.uid())
                and cm.member_role in ('owner','recruiter'))
);

create policy employment_outcomes_update on public.employment_outcomes
for update to authenticated
using (exists (select 1 from public.company_members cm
               where cm.company_id=employment_outcomes.company_id
                 and cm.user_id=(select auth.uid())
                 and cm.member_role in ('owner','recruiter')))
with check (
  current_setting('talentos.outcome_write', true)='1'
  and exists (select 1 from public.company_members cm
              where cm.company_id=employment_outcomes.company_id
                and cm.user_id=(select auth.uid())
                and cm.member_role in ('owner','recruiter'))
);

create or replace function public.record_employment_outcome(
  p_application_id uuid,
  p_checkpoint text,
  p_performance_score numeric default null,
  p_ramp_up_days smallint default null,
  p_retention_status text default 'ativo',
  p_skill_feedback jsonb default '{}'::jsonb,
  p_manager_note text default null
) returns public.employment_outcomes
language plpgsql security invoker set search_path=public
as $$
declare app public.applications; company_id uuid; result public.employment_outcomes;
begin
  if (select auth.uid()) is null then raise exception 'Autenticação necessária'; end if;
  if p_checkpoint not in ('30d','60d','90d','saida') then raise exception 'Checkpoint inválido'; end if;
  if p_performance_score is not null and (p_performance_score<0 or p_performance_score>100) then raise exception 'Performance deve estar entre 0 e 100'; end if;
  if p_ramp_up_days is not null and p_ramp_up_days<0 then raise exception 'Ramp-up não pode ser negativo'; end if;
  if p_retention_status not in ('ativo','desligado','promovido','transferido') then raise exception 'Status de retenção inválido'; end if;
  select a.* into app from public.applications a where a.id=p_application_id;
  if not found then raise exception 'Candidatura não encontrada'; end if;
  if app.status<>'contratado' then raise exception 'Outcome só pode ser registrado após contratação'; end if;
  select j.company_id into company_id from public.jobs j where j.id=app.job_id;
  if company_id is null then raise exception 'Empresa da vaga não encontrada'; end if;
  if not exists (select 1 from public.company_members cm
                 where cm.company_id=company_id and cm.user_id=(select auth.uid())
                   and cm.member_role in ('owner','recruiter')) then
    raise exception 'Sem permissão para registrar outcome';
  end if;
  perform set_config('talentos.outcome_write','1',true);
  insert into public.employment_outcomes(
    application_id,candidate_id,job_id,company_id,checkpoint,performance_score,ramp_up_days,
    retention_status,skill_feedback,manager_note,created_by,updated_at
  ) values(
    app.id,app.candidate_id,app.job_id,company_id,p_checkpoint,p_performance_score,p_ramp_up_days,
    p_retention_status,coalesce(p_skill_feedback,'{}'::jsonb),p_manager_note,(select auth.uid()),now()
  )
  on conflict(application_id,checkpoint)
  do update set performance_score=excluded.performance_score,ramp_up_days=excluded.ramp_up_days,
    retention_status=excluded.retention_status,skill_feedback=excluded.skill_feedback,
    manager_note=excluded.manager_note,updated_at=now(),created_by=(select auth.uid())
  returning * into result;
  return result;
end;
$$;

create or replace function public.guard_employment_outcome_write()
returns trigger language plpgsql set search_path=public
as $$
begin
  if current_setting('talentos.outcome_write', true)<>'1' then raise exception 'Alteração de outcome deve usar record_employment_outcome'; end if;
  if tg_op='INSERT' and new.created_by<>(select auth.uid()) then raise exception 'Autor do outcome inválido'; end if;
  if tg_op='UPDATE' and new.company_id<>old.company_id then raise exception 'Empresa do outcome não pode mudar'; end if;
  if tg_op='UPDATE' and new.application_id<>old.application_id then raise exception 'Candidatura do outcome não pode mudar'; end if;
  if tg_op='UPDATE' and new.candidate_id<>old.candidate_id then raise exception 'Candidato do outcome não pode mudar'; end if;
  if tg_op='UPDATE' and new.job_id<>old.job_id then raise exception 'Vaga do outcome não pode mudar'; end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_employment_outcome_write on public.employment_outcomes;
create trigger trg_guard_employment_outcome_write
before insert or update on public.employment_outcomes
for each row execute function public.guard_employment_outcome_write();

revoke execute on function public.record_employment_outcome(uuid,text,numeric,smallint,text,jsonb,text) from public, anon;
grant execute on function public.record_employment_outcome(uuid,text,numeric,smallint,text,jsonb,text) to authenticated;
