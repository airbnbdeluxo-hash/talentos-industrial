create or replace function public.get_company_outcome_skill_intelligence()
returns table(
  skill_id uuid,
  capability_node_id uuid,
  skill_name text,
  signal_count bigint,
  utilized_count bigint,
  needs_development_count bigint,
  training_needed_count bigint,
  avg_manager_rating numeric,
  avg_performance numeric,
  avg_ramp_up_days numeric
)
language sql
security invoker
set search_path = public
as $$
  select oss.skill_id, oss.capability_node_id, s.name as skill_name,
    count(*) as signal_count,
    count(*) filter (where oss.signal_status='utilizada') as utilized_count,
    count(*) filter (where oss.signal_status='necessita_desenvolvimento') as needs_development_count,
    count(*) filter (where oss.training_needed) as training_needed_count,
    round(avg(oss.manager_rating)::numeric,2) as avg_manager_rating,
    round(avg(eo.performance_score)::numeric,2) as avg_performance,
    round(avg(eo.ramp_up_days)::numeric,2) as avg_ramp_up_days
  from public.employment_outcome_skill_signals oss
  join public.skills s on s.id=oss.skill_id
  join public.employment_outcomes eo on eo.id=oss.outcome_id
  where exists (
    select 1 from public.company_members cm
    where cm.company_id=eo.company_id
      and cm.user_id=(select auth.uid())
      and cm.member_role in ('owner','recruiter','viewer')
  )
  group by oss.skill_id, oss.capability_node_id, s.name
  order by signal_count desc, needs_development_count desc, s.name asc
$$;
revoke execute on function public.get_company_outcome_skill_intelligence() from public, anon;
grant execute on function public.get_company_outcome_skill_intelligence() to authenticated;
