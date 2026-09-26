-- TalentOS backend matching engine
create index if not exists idx_candidate_profiles_searchable_city
  on public.candidate_profiles(searchable, city);

create index if not exists idx_candidate_skills_candidate_skill
  on public.candidate_skills(candidate_id, skill_id, proficiency, verified);

create index if not exists idx_job_skills_job_required
  on public.job_skills(job_id, required, skill_id);

create index if not exists idx_talent_preferences_shifts
  on public.talent_preferences using gin(preferred_shifts);

drop function if exists public.generate_matches_for_job(uuid);

create or replace function public.generate_matches_for_job(p_job_id uuid)
returns table(candidate_id uuid, score numeric(5,2), reasons jsonb, gaps jsonb)
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_is_member boolean;
  v_job_exists boolean;
begin
  if (select auth.uid()) is null then
    raise exception 'authentication required';
  end if;

  select exists(
    select 1
    from public.company_members cm
    join public.jobs j on j.company_id = cm.company_id
    where j.id = p_job_id
      and cm.user_id = (select auth.uid())
      and cm.member_role in ('owner','recruiter')
  ) into v_is_member;

  if not v_is_member then
    raise exception 'not authorized for this job';
  end if;

  select exists(select 1 from public.jobs where id = p_job_id)
    into v_job_exists;

  if not v_job_exists then
    raise exception 'job not found';
  end if;

  delete from public.matches where job_id = p_job_id;

  return query
  with req as (
    select js.skill_id, s.name, js.min_proficiency,
           greatest(coalesce(js.weight,1),0.001) as weight
    from public.job_skills js
    join public.skills s on s.id = js.skill_id
    where js.job_id = p_job_id and js.required
  ),
  req_totals as (
    select coalesce(sum(weight),0) as total_weight from req
  ),
  scored as (
    select
      cp.profile_id as candidate_id,
      j.city as job_city,
      j.salary_min,
      j.salary_max,
      j.shift,
      cp.city as candidate_city,
      cp.desired_salary,
      coalesce(tp.preferred_shifts, '{}'::text[]) as preferred_shifts,
      coalesce(sum(case
        when cs.skill_id is not null and cs.proficiency >= r.min_proficiency then r.weight
        else 0 end),0) as covered_weight,
      coalesce(sum(case
        when cs.skill_id is not null and cs.proficiency > 0
          then least(cs.proficiency::numeric / greatest(r.min_proficiency,1), 1) * r.weight
        else 0 end),0) as partial_weight,
      coalesce(sum(case
        when cs.skill_id is not null and cs.proficiency >= r.min_proficiency and cs.verified
          then r.weight else 0 end),0) as verified_weight,
      coalesce(
        jsonb_agg(r.name order by r.name) filter (
          where cs.skill_id is null or cs.proficiency < r.min_proficiency
        ),
        '[]'::jsonb
      ) as gaps
    from public.candidate_profiles cp
    cross join public.jobs j
    cross join req r
    left join public.candidate_skills cs
      on cs.candidate_id = cp.profile_id and cs.skill_id = r.skill_id
    left join public.talent_preferences tp
      on tp.candidate_id = cp.profile_id
    where j.id = p_job_id and cp.searchable
    group by cp.profile_id,j.city,j.salary_min,j.salary_max,j.shift,
             cp.city,cp.desired_salary,tp.preferred_shifts
  ),
  calc as (
    select
      s.*,
      case when rt.total_weight = 0 then 0
           else greatest(0, least(1, s.covered_weight / rt.total_weight)) end as coverage_ratio,
      case when rt.total_weight = 0 then 0
           else greatest(0, least(1, s.partial_weight / rt.total_weight)) end as partial_ratio,
      case when rt.total_weight = 0 then 0
           else greatest(0, least(1, s.verified_weight / rt.total_weight)) end as verified_ratio,
      case
        when s.shift is null or s.preferred_shifts = '{}'::text[] then 0.5
        when s.shift = any(s.preferred_shifts) then 1
        else 0
      end as shift_ratio,
      case when lower(coalesce(s.candidate_city,'')) = lower(coalesce(s.job_city,''))
                and coalesce(s.candidate_city,'') <> '' then 1 else 0 end as city_ratio,
      case
        when s.desired_salary is null then 0.5
        when s.salary_min is null and s.salary_max is null then 0.5
        when s.salary_min is not null and s.salary_max is not null
          and s.desired_salary between s.salary_min and s.salary_max then 1
        when s.salary_min is not null and s.desired_salary >= s.salary_min
          and s.salary_max is null then 1
        when s.salary_max is not null and s.desired_salary <= s.salary_max
          and s.salary_min is null then 1
        else 0
      end as salary_ratio
    from scored s
    cross join req_totals rt
  ),
  final as (
    select
      c.candidate_id,
      round(100 * (
        0.60 * c.coverage_ratio
        + 0.10 * c.partial_ratio
        + 0.20 * c.verified_ratio
        + 0.05 * c.shift_ratio
        + 0.025 * c.city_ratio
        + 0.025 * c.salary_ratio
      ),2) as score,
      jsonb_build_array(
        case when c.coverage_ratio >= 0.999 then 'Skills obrigatórias cobertas'
             when c.partial_ratio > 0 then 'Parte das skills obrigatórias disponível'
             else 'Cobertura de skills baixa' end,
        case when c.verified_ratio > 0.999 then 'Evidências verificadas nas skills'
             when c.verified_ratio > 0 then 'Há evidências verificadas em parte das skills'
             else 'Poucas evidências verificadas' end,
        case when c.shift_ratio = 1 then 'Preferência de turno compatível'
             when c.shift_ratio = 0.5 then 'Turno sem preferência informada'
             else 'Turno fora da preferência' end,
        case when c.city_ratio = 1 then 'Mesma cidade da vaga'
             else 'Cidade diferente da vaga' end,
        case when c.salary_ratio = 1 then 'Pretensão dentro da faixa'
             when c.salary_ratio = 0.5 then 'Pretensão salarial não informada ou faixa incompleta'
             else 'Pretensão fora da faixa' end
      ) as reasons,
      c.gaps
    from calc c
  )
  insert into public.matches(job_id,candidate_id,score,reasons,gaps)
  select p_job_id,f.candidate_id,f.score,f.reasons,f.gaps
  from final f
  on conflict (job_id,candidate_id)
  do update set score=excluded.score,reasons=excluded.reasons,gaps=excluded.gaps,created_at=now()
  returning public.matches.candidate_id,public.matches.score,public.matches.reasons,public.matches.gaps;
end;
$$;

drop policy if exists matches_member_insert on public.matches;
create policy matches_member_insert on public.matches
for insert to authenticated
with check (
  exists (
    select 1 from public.jobs j
    join public.company_members cm on cm.company_id=j.company_id
    where j.id=matches.job_id
      and cm.user_id=(select auth.uid())
      and cm.member_role in ('owner','recruiter')
  )
);

drop policy if exists matches_member_update on public.matches;
create policy matches_member_update on public.matches
for update to authenticated
using (
  exists (
    select 1 from public.jobs j
    join public.company_members cm on cm.company_id=j.company_id
    where j.id=matches.job_id
      and cm.user_id=(select auth.uid())
      and cm.member_role in ('owner','recruiter')
  )
)
with check (
  exists (
    select 1 from public.jobs j
    join public.company_members cm on cm.company_id=j.company_id
    where j.id=matches.job_id
      and cm.user_id=(select auth.uid())
      and cm.member_role in ('owner','recruiter')
  )
);

drop policy if exists matches_member_delete on public.matches;
create policy matches_member_delete on public.matches
for delete to authenticated
using (
  exists (
    select 1 from public.jobs j
    join public.company_members cm on cm.company_id=j.company_id
    where j.id=matches.job_id
      and cm.user_id=(select auth.uid())
      and cm.member_role in ('owner','recruiter')
  )
);

revoke all on function public.generate_matches_for_job(uuid) from public;
grant execute on function public.generate_matches_for_job(uuid) to authenticated;
