-- TalentOS RLS/security regression checks.
-- Run in Supabase SQL Editor with sufficient privileges before release.
do $$
declare
  required_tables text[] := array[
    'profiles','companies','skills','candidate_profiles','candidate_skills',
    'jobs','job_skills','matches','applications','company_members',
    'skill_evidence','skill_assessments','training_recommendations',
    'talent_preferences','application_events','challenge_library','challenge_attempts'
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

  if has_table_privilege('authenticated','public.challenge_answer_keys','select') then
    raise exception 'authenticated can select challenge answer keys';
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

  raise notice 'TalentOS RLS/security checks passed';
end $$;