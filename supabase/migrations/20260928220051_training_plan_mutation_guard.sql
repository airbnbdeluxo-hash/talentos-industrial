-- TalentOS: guard both generated inserts and generated upserts
drop policy if exists training_generation_update on public.training_recommendations;
create policy training_generation_update on public.training_recommendations
for update to authenticated
using(
  candidate_id=(select auth.uid())
  or exists(
    select 1
    from public.jobs j
    join public.company_members cm on cm.company_id=j.company_id
    where j.id=training_recommendations.job_id
      and cm.user_id=(select auth.uid())
      and cm.member_role in ('owner','recruiter')
  )
)
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
declare
  insert_ok boolean := (select current_setting('talentos.training_generation',true))='1';
begin
  if not insert_ok then
    raise exception 'Criação direta de plano de treinamento não permitida';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_training_recommendation_insert on public.training_recommendations;
create trigger trg_guard_training_recommendation_insert
before insert on public.training_recommendations
for each row execute function public.guard_training_recommendation_insert();

create or replace function public.guard_training_recommendation_update()
returns trigger
language plpgsql
security invoker
set search_path=public
as $$
declare
  generated_ok boolean := (select current_setting('talentos.training_generation',true))='1';
  candidate_ok boolean := (select current_setting('talentos.training_candidate_update',true))='1';
begin
  if not generated_ok and not candidate_ok then
    raise exception 'Edição direta de plano de treinamento não permitida';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_training_recommendation_update on public.training_recommendations;
create trigger trg_guard_training_recommendation_update
before update on public.training_recommendations
for each row execute function public.guard_training_recommendation_update();

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

  perform set_config('talentos.training_candidate_update','1',true);

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

revoke all on function public.update_training_recommendation(uuid,text,text) from public;
grant execute on function public.update_training_recommendation(uuid,text,text) to authenticated;