-- Consolidate admin access into action-specific RLS policies on high-traffic tables.
-- This preserves existing authorization semantics while avoiding overlapping ALL policies.

-- profiles
drop policy if exists admin_full_access_profiles on public.profiles;
alter policy profile_self_select on public.profiles
  using (private.is_admin() or (select auth.uid()) = id);
alter policy profile_self_update_safe on public.profiles
  using (private.is_admin() or (select auth.uid()) = id)
  with check (
    private.is_admin()
    or ((select auth.uid()) = id and role::text = private.current_role())
  );
drop policy if exists profiles_admin_insert on public.profiles;
create policy profiles_admin_insert on public.profiles
  for insert to authenticated
  with check (private.is_admin());
drop policy if exists profiles_admin_delete on public.profiles;
create policy profiles_admin_delete on public.profiles
  for delete to authenticated
  using (private.is_admin());

-- candidate_profiles
drop policy if exists admin_full_access_candidate_profiles on public.candidate_profiles;
alter policy candidate_insert on public.candidate_profiles
  with check (private.is_admin() or profile_id = (select auth.uid()));
alter policy candidate_self on public.candidate_profiles
  using (
    private.is_admin()
    or profile_id = (select auth.uid())
    or (
      searchable
      and private.current_role() = any (array['empresa'::text,'admin'::text])
      and exists (
        select 1
        from public.company_members cm
        where cm.user_id = (select auth.uid())
          and cm.member_role = any (array['owner'::text,'recruiter'::text,'viewer'::text])
      )
    )
  );
alter policy candidate_update on public.candidate_profiles
  using (private.is_admin() or profile_id = (select auth.uid()))
  with check (private.is_admin() or profile_id = (select auth.uid()));
drop policy if exists candidate_profiles_admin_delete on public.candidate_profiles;
create policy candidate_profiles_admin_delete on public.candidate_profiles
  for delete to authenticated
  using (private.is_admin());

-- candidate_skills
drop policy if exists admin_full_access_candidate_skills on public.candidate_skills;
alter policy candidate_skills_insert on public.candidate_skills
  with check (private.is_admin() or candidate_id = (select auth.uid()));
alter policy candidate_skills_access on public.candidate_skills
  using (
    private.is_admin()
    or candidate_id = (select auth.uid())
    or (
      private.current_role() = any (array['empresa'::text,'admin'::text])
      and exists (
        select 1 from public.candidate_profiles cp
        where cp.profile_id = candidate_skills.candidate_id
          and cp.searchable
      )
      and exists (
        select 1 from public.company_members cm
        where cm.user_id = (select auth.uid())
          and cm.member_role = any (array['owner'::text,'recruiter'::text,'viewer'::text])
      )
    )
  );
alter policy candidate_skills_update on public.candidate_skills
  using (private.is_admin() or candidate_id = (select auth.uid()))
  with check (private.is_admin() or candidate_id = (select auth.uid()));
alter policy candidate_skills_delete on public.candidate_skills
  using (private.is_admin() or candidate_id = (select auth.uid()));

-- jobs
drop policy if exists admin_full_access_jobs on public.jobs;
alter policy jobs_member_write on public.jobs
  with check (
    private.is_admin()
    or exists (
      select 1 from public.company_members cm
      where cm.company_id = jobs.company_id
        and cm.user_id = (select auth.uid())
        and cm.member_role = any (array['owner'::text,'recruiter'::text])
    )
  );
alter policy jobs_read on public.jobs
  using (
    private.is_admin()
    or status = 'aberta'
    or exists (
      select 1 from public.company_members cm
      where cm.company_id = jobs.company_id
        and cm.user_id = (select auth.uid())
    )
  );
alter policy jobs_member_update on public.jobs
  using (
    private.is_admin()
    or exists (
      select 1 from public.company_members cm
      where cm.company_id = jobs.company_id
        and cm.user_id = (select auth.uid())
        and cm.member_role = any (array['owner'::text,'recruiter'::text])
    )
  )
  with check (
    private.is_admin()
    or exists (
      select 1 from public.company_members cm
      where cm.company_id = jobs.company_id
        and cm.user_id = (select auth.uid())
        and cm.member_role = any (array['owner'::text,'recruiter'::text])
    )
  );
drop policy if exists jobs_admin_delete on public.jobs;
create policy jobs_admin_delete on public.jobs
  for delete to authenticated
  using (private.is_admin());

-- applications
drop policy if exists admin_full_access_applications on public.applications;
alter policy applications_insert on public.applications
  with check (private.is_admin() or candidate_id = (select auth.uid()));
alter policy applications_access on public.applications
  using (
    private.is_admin()
    or candidate_id = (select auth.uid())
    or exists (
      select 1
      from public.jobs j
      join public.company_members cm on cm.company_id = j.company_id
      where j.id = applications.job_id
        and cm.user_id = (select auth.uid())
    )
  );
alter policy applications_company_update on public.applications
  using (
    private.is_admin()
    or exists (
      select 1
      from public.jobs j
      join public.company_members cm on cm.company_id = j.company_id
      where j.id = applications.job_id
        and cm.user_id = (select auth.uid())
        and cm.member_role = any (array['owner'::text,'recruiter'::text])
    )
  )
  with check (
    private.is_admin()
    or exists (
      select 1
      from public.jobs j
      join public.company_members cm on cm.company_id = j.company_id
      where j.id = applications.job_id
        and cm.user_id = (select auth.uid())
        and cm.member_role = any (array['owner'::text,'recruiter'::text])
    )
  );
drop policy if exists applications_admin_delete on public.applications;
create policy applications_admin_delete on public.applications
  for delete to authenticated
  using (private.is_admin());

-- matches
drop policy if exists admin_full_access_matches on public.matches;
alter policy matches_member_insert on public.matches
  with check (
    private.is_admin()
    or exists (
      select 1
      from public.jobs j
      join public.company_members cm on cm.company_id = j.company_id
      where j.id = matches.job_id
        and cm.user_id = (select auth.uid())
        and cm.member_role = any (array['owner'::text,'recruiter'::text])
    )
  );
alter policy matches_access on public.matches
  using (
    private.is_admin()
    or candidate_id = (select auth.uid())
    or exists (
      select 1
      from public.jobs j
      join public.company_members cm on cm.company_id = j.company_id
      where j.id = matches.job_id
        and cm.user_id = (select auth.uid())
    )
  );
alter policy matches_member_update on public.matches
  using (
    private.is_admin()
    or exists (
      select 1
      from public.jobs j
      join public.company_members cm on cm.company_id = j.company_id
      where j.id = matches.job_id
        and cm.user_id = (select auth.uid())
        and cm.member_role = any (array['owner'::text,'recruiter'::text])
    )
  )
  with check (
    private.is_admin()
    or exists (
      select 1
      from public.jobs j
      join public.company_members cm on cm.company_id = j.company_id
      where j.id = matches.job_id
        and cm.user_id = (select auth.uid())
        and cm.member_role = any (array['owner'::text,'recruiter'::text])
    )
  );
alter policy matches_member_delete on public.matches
  using (
    private.is_admin()
    or exists (
      select 1
      from public.jobs j
      join public.company_members cm on cm.company_id = j.company_id
      where j.id = matches.job_id
        and cm.user_id = (select auth.uid())
        and cm.member_role = any (array['owner'::text,'recruiter'::text])
    )
  );
