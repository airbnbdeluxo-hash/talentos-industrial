-- TalentOS RLS/security regression checks.
-- Run in Supabase SQL Editor with sufficient privileges before release.
do $$
declare
  required_tables text[] := array[
    'profiles','companies','skills','candidate_profiles','candidate_skills',
    'jobs','job_skills','matches','applications','company_members',
    'skill_evidence','skill_assessments','training_recommendations',
    'talent_preferences','application_events','challenge_library','challenge_attempts','capability_nodes','capability_edges','employment_outcomes','employment_outcome_skill_signals'
  ];
  t text;
begin
  foreach t in array required_tables loop
    if not exists(
      select 1 from pg_class c
      join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='public' and c.relname=t and c.relrowsecurity
    ) then
      raise exception 'RLS missing on public.%',t;
    end if;
  end loop;

  if has_function_privilege('anon','public.generate_matches_for_job(uuid)','execute') then
    raise exception 'anon can execute generate_matches_for_job';
  end if;
  if not has_function_privilege('authenticated','public.generate_matches_for_job(uuid)','execute') then
    raise exception 'authenticated cannot execute generate_matches_for_job';
  end if;

  if has_function_privilege('anon','public.start_challenge(uuid,uuid)','execute') then
    raise exception 'anon can execute start_challenge';
  end if;
  if has_function_privilege('anon','public.complete_challenge(uuid,jsonb)','execute') then
    raise exception 'anon can execute complete_challenge';
  end if;

  if not exists(
    select 1 from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='complete_challenge' and not p.prosecdef
  ) then
    raise exception 'complete_challenge must remain SECURITY INVOKER';
  end if;

  if not exists(select 1 from pg_trigger where tgname='protect_profile_role') then
    raise exception 'profile role protection trigger missing';
  end if;

  if not exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='skill_evidence_storage_insert') then
    raise exception 'evidence storage insert policy missing';
  end if;

  if not exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='skill_evidence_storage_select') then
    raise exception 'evidence storage select policy missing';
  end if;

  if not exists(select 1 from pg_trigger where tgname='enforce_evidence_validation_state') then
    raise exception 'evidence validation trigger missing';
  end if;

  if exists(select 1 from pg_policies where schemaname='public' and tablename='skill_evidence' and policyname='evidence_update') then
    raise exception 'candidate evidence update policy must remain removed';
  end if;

  if not exists(select 1 from pg_policies where schemaname='public' and tablename='skill_evidence' and policyname='evidence_reviewer_update') then
    raise exception 'reviewer evidence update policy missing';
  end if;

  if not exists(select 1 from pg_policies where schemaname='public' and tablename='skill_evidence' and policyname='evidence_delete') then
    raise exception 'evidence delete policy missing';
  end if;

  if has_table_privilege('anon','public.capability_nodes','select') then
    raise exception 'anon can read capability_nodes';
  end if;
  if not has_table_privilege('authenticated','public.capability_nodes','select') then
    raise exception 'authenticated cannot read capability_nodes';
  end if;
  if not exists(select 1 from pg_policies where schemaname='public' and tablename='capability_nodes' and policyname='capability_nodes_read') then
    raise exception 'capability nodes read policy missing';
  end if;
  if not exists(select 1 from pg_policies where schemaname='public' and tablename='capability_edges' and policyname='capability_edges_read') then
    raise exception 'capability edges read policy missing';
  end if;

  if has_function_privilege('anon','public.generate_training_plan_for_job(uuid,uuid)','execute') then
    raise exception 'anon can execute generate_training_plan_for_job';
  end if;
  if not has_function_privilege('authenticated','public.generate_training_plan_for_job(uuid,uuid)','execute') then
    raise exception 'authenticated cannot execute generate_training_plan_for_job';
  end if;
  if exists(
    select 1 from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='generate_training_plan_for_job' and p.prosecdef
  ) then
    raise exception 'generate_training_plan_for_job must remain SECURITY INVOKER';
  end if;
  if not exists(select 1 from pg_policies where schemaname='public' and tablename='training_recommendations' and policyname='training_generation_insert') then
    raise exception 'training generation insert policy missing';
  end if;
  if not exists(select 1 from pg_trigger where tgname='trg_guard_training_recommendation_insert') then
    raise exception 'training recommendation insert guard missing';
  end if;
  if not exists(select 1 from pg_policies where schemaname='public' and tablename='training_recommendations' and policyname='training_update') then
    raise exception 'training generation update policy missing';
  end if;
  if not exists(select 1 from pg_trigger where tgname='trg_guard_training_recommendation_update') then
    raise exception 'training recommendation update guard missing';
  end if;
  if exists(select 1 from pg_policies where schemaname='public' and tablename='training_recommendations' and policyname='candidate_training_update') then
    raise exception 'legacy candidate_training_update policy must remain removed';
  end if;

  if has_table_privilege('anon','public.employment_outcomes','select') then
    raise exception 'anon can read employment_outcomes';
  end if;
  if not has_table_privilege('authenticated','public.employment_outcomes','select') then
    raise exception 'authenticated cannot read employment_outcomes';
  end if;
  if has_function_privilege('anon','public.record_employment_outcome(uuid,text,numeric,smallint,text,jsonb,text)','execute') then
    raise exception 'anon can execute record_employment_outcome';
  end if;
  if not has_function_privilege('authenticated','public.record_employment_outcome(uuid,text,numeric,smallint,text,jsonb,text)','execute') then
    raise exception 'authenticated cannot execute record_employment_outcome';
  end if;
  if not exists(
    select 1 from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='record_employment_outcome' and not p.prosecdef
  ) then
    raise exception 'record_employment_outcome must remain SECURITY INVOKER';
  end if;
  if not exists(select 1 from pg_trigger where tgname='trg_guard_employment_outcome_write') then
    raise exception 'employment outcome write guard missing';
  end if;
  if not exists(select 1 from pg_policies where schemaname='public' and tablename='employment_outcomes' and policyname='employment_outcomes_visibility') then
    raise exception 'employment outcome visibility policy missing';
  end if;
  if not has_table_privilege('authenticated','public.employment_outcome_skill_signals','select') then
    raise exception 'authenticated cannot read employment_outcome_skill_signals';
  end if;
  if has_table_privilege('anon','public.employment_outcome_skill_signals','select') then
    raise exception 'anon can read employment_outcome_skill_signals';
  end if;
  if has_function_privilege('anon','public.save_employment_outcome_skill_signal(uuid,uuid,text,smallint,boolean,text)','execute') then
    raise exception 'anon can execute save_employment_outcome_skill_signal';
  end if;
  if not has_function_privilege('authenticated','public.save_employment_outcome_skill_signal(uuid,uuid,text,smallint,boolean,text)','execute') then
    raise exception 'authenticated cannot execute save_employment_outcome_skill_signal';
  end if;
  if exists(
    select 1 from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='save_employment_outcome_skill_signal' and p.prosecdef
  ) then
    raise exception 'save_employment_outcome_skill_signal must remain SECURITY INVOKER';
  end if;
  if not exists(select 1 from pg_trigger where tgname='trg_guard_employment_outcome_skill_write') then
    raise exception 'outcome skill signal write guard missing';
  end if;
  if not exists(select 1 from pg_policies where schemaname='public' and tablename='employment_outcome_skill_signals' and policyname='outcome_skill_signals_visibility') then
    raise exception 'outcome skill signal visibility policy missing';
  end if;

  raise notice 'TalentOS RLS/security checks passed';
end $$;