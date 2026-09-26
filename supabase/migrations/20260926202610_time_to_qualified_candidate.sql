-- Measure the system's time to first qualified candidate (readiness >= 80).
alter table public.jobs
  add column if not exists qualified_candidate_at timestamptz;

create index if not exists idx_jobs_qualified_candidate_at
  on public.jobs(qualified_candidate_at)
  where qualified_candidate_at is not null;

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
  if (select auth.uid()) is null then raise exception 'authentication required'; end if;

  select exists(
    select 1 from public.company_members cm
    join public.jobs j on j.company_id=cm.company_id
    where j.id=p_job_id
      and cm.user_id=(select auth.uid())
      and cm.member_role in ('owner','recruiter')
  ) into v_is_member;

  if not v_is_member then raise exception 'not authorized for this job'; end if;

  select exists(select 1 from public.jobs where id=p_job_id) into v_job_exists;
  if not v_job_exists then raise exception 'job not found'; end if;

  delete from public.matches where job_id=p_job_id;

  insert into public.matches(job_id,candidate_id,score,reasons,gaps)
  with req as (
    select js.skill_id,s.name,js.min_proficiency,greatest(coalesce(js.weight,1),0.001) weight
    from public.job_skills js join public.skills s on s.id=js.skill_id
    where js.job_id=p_job_id and js.required
  ),
  req_totals as (select coalesce(sum(weight),0) total_weight from req),
  scored as (
    select cp.profile_id candidate_id,j.city job_city,j.salary_min,j.salary_max,j.shift,
      cp.city candidate_city,cp.desired_salary,
      coalesce(tp.preferred_shifts,'{}'::text[]) preferred_shifts,
      coalesce(sum(case when cs.skill_id is not null and cs.proficiency>=r.min_proficiency then r.weight else 0 end),0) covered_weight,
      coalesce(sum(case when cs.skill_id is not null and cs.proficiency>0 then least(cs.proficiency::numeric/greatest(r.min_proficiency,1),1)*r.weight else 0 end),0) partial_weight,
      coalesce(sum(case when cs.skill_id is not null and cs.proficiency>=r.min_proficiency and cs.verified then r.weight else 0 end),0) verified_weight,
      coalesce(jsonb_agg(r.name order by r.name) filter(where cs.skill_id is null or cs.proficiency<r.min_proficiency),'[]'::jsonb) gaps
    from public.candidate_profiles cp
    cross join public.jobs j cross join req r
    left join public.candidate_skills cs on cs.candidate_id=cp.profile_id and cs.skill_id=r.skill_id
    left join public.talent_preferences tp on tp.candidate_id=cp.profile_id
    where j.id=p_job_id and cp.searchable
    group by cp.profile_id,j.city,j.salary_min,j.salary_max,j.shift,cp.city,cp.desired_salary,tp.preferred_shifts
  ),
  calc as (
    select s.*,
      case when rt.total_weight=0 then 0 else greatest(0,least(1,s.covered_weight/rt.total_weight)) end coverage_ratio,
      case when rt.total_weight=0 then 0 else greatest(0,least(1,s.partial_weight/rt.total_weight)) end partial_ratio,
      case when rt.total_weight=0 then 0 else greatest(0,least(1,s.verified_weight/rt.total_weight)) end verified_ratio,
      case when s.shift is null or s.preferred_shifts='{}'::text[] then 0.5 when s.shift=any(s.preferred_shifts) then 1 else 0 end shift_ratio,
      case when lower(coalesce(s.candidate_city,''))=lower(coalesce(s.job_city,'')) and coalesce(s.candidate_city,'')<>'' then 1 else 0 end city_ratio,
      case
        when s.desired_salary is null then 0.5
        when s.salary_min is null and s.salary_max is null then 0.5
        when s.salary_min is not null and s.salary_max is not null and s.desired_salary between s.salary_min and s.salary_max then 1
        when s.salary_min is not null and s.desired_salary>=s.salary_min and s.salary_max is null then 1
        when s.salary_max is not null and s.desired_salary<=s.salary_max and s.salary_min is null then 1
        else 0
      end salary_ratio
    from scored s cross join req_totals rt
  ),
  final as (
    select c.candidate_id,
      round(100*(0.60*c.coverage_ratio+0.10*c.partial_ratio+0.20*c.verified_ratio+0.05*c.shift_ratio+0.025*c.city_ratio+0.025*c.salary_ratio),2) score,
      jsonb_build_array(
        case when c.coverage_ratio>=0.999 then 'Skills obrigatórias cobertas' when c.partial_ratio>0 then 'Parte das skills obrigatórias disponível' else 'Cobertura de skills baixa' end,
        case when c.verified_ratio>0.999 then 'Evidências verificadas nas skills' when c.verified_ratio>0 then 'Há evidências verificadas em parte das skills' else 'Poucas evidências verificadas' end,
        case when c.shift_ratio=1 then 'Preferência de turno compatível' when c.shift_ratio=0.5 then 'Turno sem preferência informada' else 'Turno fora da preferência' end,
        case when c.city_ratio=1 then 'Mesma cidade da vaga' else 'Cidade diferente da vaga' end,
        case when c.salary_ratio=1 then 'Pretensão dentro da faixa' when c.salary_ratio=0.5 then 'Pretensão salarial não informada ou faixa incompleta' else 'Pretensão fora da faixa' end
      ) reasons,
      c.gaps
    from calc c
  )
  select p_job_id,f.candidate_id,f.score,f.reasons,f.gaps from final f;

  update public.jobs j
  set qualified_candidate_at=coalesce(j.qualified_candidate_at,now())
  where j.id=p_job_id and exists(select 1 from public.matches m where m.job_id=p_job_id and m.score>=80);

  return query
  select m.candidate_id,m.score,m.reasons,m.gaps
  from public.matches m where m.job_id=p_job_id order by m.score desc;
end;
$$;

revoke execute on function public.generate_matches_for_job(uuid) from anon;
revoke execute on function public.generate_matches_for_job(uuid) from public;
grant execute on function public.generate_matches_for_job(uuid) to authenticated;