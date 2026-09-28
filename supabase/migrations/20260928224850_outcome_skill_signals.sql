create table public.employment_outcome_skill_signals (
  id uuid primary key default gen_random_uuid(),
  outcome_id uuid not null references public.employment_outcomes(id) on delete cascade,
  skill_id uuid not null references public.skills(id) on delete restrict,
  capability_node_id uuid references public.capability_nodes(id) on delete set null,
  signal_status text not null default 'nao_observado'
    check (signal_status in ('utilizada','necessita_desenvolvimento','nao_observado','nao_aplicavel')),
  manager_rating smallint check (manager_rating is null or manager_rating between 1 and 5),
  training_needed boolean not null default false,
  note text,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (outcome_id, skill_id)
);

create index outcome_skill_signals_skill_idx on public.employment_outcome_skill_signals(skill_id, created_at desc);
create index outcome_skill_signals_capability_idx on public.employment_outcome_skill_signals(capability_node_id) where capability_node_id is not null;

alter table public.employment_outcome_skill_signals enable row level security;
revoke all on public.employment_outcome_skill_signals from anon, authenticated;
grant select on public.employment_outcome_skill_signals to authenticated;

create policy outcome_skill_signals_visibility
on public.employment_outcome_skill_signals for select to authenticated
using (
  exists (
    select 1 from public.employment_outcomes eo
    join public.company_members cm on cm.company_id=eo.company_id
    where eo.id=employment_outcome_skill_signals.outcome_id
      and cm.user_id=(select auth.uid())
      and cm.member_role in ('owner','recruiter','viewer')
  )
);

create policy outcome_skill_signals_write
on public.employment_outcome_skill_signals for insert to authenticated
with check (
  current_setting('talentos.outcome_skill_write', true)='1'
  and exists (
    select 1 from public.employment_outcomes eo
    join public.company_members cm on cm.company_id=eo.company_id
    where eo.id=employment_outcome_skill_signals.outcome_id
      and cm.user_id=(select auth.uid())
      and cm.member_role in ('owner','recruiter')
  )
);

create policy outcome_skill_signals_update
on public.employment_outcome_skill_signals for update to authenticated
using (
  exists (
    select 1 from public.employment_outcomes eo
    join public.company_members cm on cm.company_id=eo.company_id
    where eo.id=employment_outcome_skill_signals.outcome_id
      and cm.user_id=(select auth.uid())
      and cm.member_role in ('owner','recruiter')
  )
)
with check (
  current_setting('talentos.outcome_skill_write', true)='1'
  and exists (
    select 1 from public.employment_outcomes eo
    join public.company_members cm on cm.company_id=eo.company_id
    where eo.id=employment_outcome_skill_signals.outcome_id
      and cm.user_id=(select auth.uid())
      and cm.member_role in ('owner','recruiter')
  )
);

create or replace function public.save_employment_outcome_skill_signal(
  p_outcome_id uuid, p_skill_id uuid, p_signal_status text,
  p_manager_rating smallint default null, p_training_needed boolean default false, p_note text default null
) returns public.employment_outcome_skill_signals
language plpgsql security invoker set search_path=public
as $$
declare
  eo public.employment_outcomes;
  target_node uuid;
  result public.employment_outcome_skill_signals;
begin
  if (select auth.uid()) is null then raise exception 'Autenticação necessária'; end if;
  if p_signal_status not in ('utilizada','necessita_desenvolvimento','nao_observado','nao_aplicavel') then raise exception 'Status de skill inválido'; end if;
  if p_manager_rating is not null and (p_manager_rating<1 or p_manager_rating>5) then raise exception 'Avaliação deve estar entre 1 e 5'; end if;
  select * into eo from public.employment_outcomes where id=p_outcome_id;
  if not found then raise exception 'Outcome não encontrado'; end if;
  if not exists (
    select 1 from public.company_members cm
    where cm.company_id=eo.company_id and cm.user_id=(select auth.uid()) and cm.member_role in ('owner','recruiter')
  ) then raise exception 'Sem permissão para registrar sinal de competência'; end if;
  if not exists (
    select 1 from public.job_skills js
    join public.applications a on a.job_id=js.job_id
    where a.id=eo.application_id and js.skill_id=p_skill_id
  ) then raise exception 'Skill não pertence aos requisitos da vaga'; end if;
  select cn.id into target_node
  from public.capability_nodes cn
  where cn.skill_id=p_skill_id and cn.node_type='competencia' and cn.active
  order by cn.created_at limit 1;
  perform set_config('talentos.outcome_skill_write','1',true);
  insert into public.employment_outcome_skill_signals(
    outcome_id,skill_id,capability_node_id,signal_status,manager_rating,training_needed,note,created_by,updated_at
  ) values(
    eo.id,p_skill_id,target_node,p_signal_status,p_manager_rating,coalesce(p_training_needed,false),p_note,(select auth.uid()),now()
  )
  on conflict(outcome_id,skill_id)
  do update set capability_node_id=excluded.capability_node_id,signal_status=excluded.signal_status,
    manager_rating=excluded.manager_rating,training_needed=excluded.training_needed,note=excluded.note,
    created_by=(select auth.uid()),updated_at=now()
  returning * into result;
  return result;
end;
$$;

create or replace function public.guard_employment_outcome_skill_write()
returns trigger language plpgsql set search_path=public
as $$
begin
  if current_setting('talentos.outcome_skill_write', true)<>'1' then raise exception 'Alteração de sinal deve usar save_employment_outcome_skill_signal'; end if;
  if tg_op='UPDATE' and new.outcome_id<>old.outcome_id then raise exception 'Outcome não pode mudar'; end if;
  if tg_op='UPDATE' and new.skill_id<>old.skill_id then raise exception 'Skill não pode mudar'; end if;
  if new.created_by<>(select auth.uid()) then raise exception 'Autor do sinal inválido'; end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_employment_outcome_skill_write on public.employment_outcome_skill_signals;
create trigger trg_guard_employment_outcome_skill_write
before insert or update on public.employment_outcome_skill_signals
for each row execute function public.guard_employment_outcome_skill_write();

revoke execute on function public.save_employment_outcome_skill_signal(uuid,uuid,text,smallint,boolean,text) from public, anon;
grant execute on function public.save_employment_outcome_skill_signal(uuid,uuid,text,smallint,boolean,text) to authenticated;
