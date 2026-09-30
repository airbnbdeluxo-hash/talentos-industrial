-- Consolidate admin RLS access for company, evidence, training and outcome workflows.

-- companies
drop policy if exists admin_full_access_companies on public.companies;
alter policy company_create on public.companies
  with check (
    private.is_admin()
    or (
      created_by = (select auth.uid())
      and private.current_role() = any (array['empresa'::text,'admin'::text])
    )
  );
alter policy company_self_or_member on public.companies
  using (
    private.is_admin()
    or created_by = (select auth.uid())
    or exists (
      select 1 from public.company_members cm
      where cm.company_id = companies.id
        and cm.user_id = (select auth.uid())
    )
  );
drop policy if exists companies_admin_update on public.companies;
create policy companies_admin_update on public.companies
  for update to authenticated
  using (private.is_admin())
  with check (private.is_admin());
drop policy if exists companies_admin_delete on public.companies;
create policy companies_admin_delete on public.companies
  for delete to authenticated
  using (private.is_admin());

-- company_members
drop policy if exists admin_full_access_company_members on public.company_members;
alter policy member_create_owner on public.company_members
  with check (
    private.is_admin()
    or (
      user_id = (select auth.uid())
      and private.current_role() = any (array['empresa'::text,'admin'::text])
      and exists (
        select 1 from public.companies c
        where c.id = company_members.company_id
          and c.created_by = (select auth.uid())
      )
    )
  );
alter policy member_self on public.company_members
  using (private.is_admin() or user_id = (select auth.uid()));
drop policy if exists company_members_admin_update on public.company_members;
create policy company_members_admin_update on public.company_members
  for update to authenticated
  using (private.is_admin())
  with check (private.is_admin());
drop policy if exists company_members_admin_delete on public.company_members;
create policy company_members_admin_delete on public.company_members
  for delete to authenticated
  using (private.is_admin());

-- job_skills
drop policy if exists admin_full_access_job_skills on public.job_skills;
alter policy jobskills_write on public.job_skills
  with check (
    private.is_admin()
    or exists (
      select 1
      from public.jobs j
      join public.company_members cm on cm.company_id = j.company_id
      where j.id = job_skills.job_id
        and cm.user_id = (select auth.uid())
        and cm.member_role = any (array['owner'::text,'recruiter'::text])
    )
  );
alter policy jobskills_access on public.job_skills
  using (
    private.is_admin()
    or exists (
      select 1
      from public.jobs j
      where j.id = job_skills.job_id
        and (
          j.status = 'aberta'
          or exists (
            select 1 from public.company_members cm
            where cm.company_id = j.company_id
              and cm.user_id = (select auth.uid())
          )
        )
    )
  );
alter policy jobskills_update on public.job_skills
  using (
    private.is_admin()
    or exists (
      select 1
      from public.jobs j
      join public.company_members cm on cm.company_id = j.company_id
      where j.id = job_skills.job_id
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
      where j.id = job_skills.job_id
        and cm.user_id = (select auth.uid())
        and cm.member_role = any (array['owner'::text,'recruiter'::text])
    )
  );
drop policy if exists job_skills_admin_delete on public.job_skills;
create policy job_skills_admin_delete on public.job_skills
  for delete to authenticated
  using (private.is_admin());

-- skill_evidence
drop policy if exists admin_full_access_skill_evidence on public.skill_evidence;
alter policy evidence_insert on public.skill_evidence
  with check (private.is_admin() or candidate_id = (select auth.uid()));
alter policy evidence_access on public.skill_evidence
  using (
    private.is_admin()
    or candidate_id = (select auth.uid())
    or (
      private.current_role() = any (array['empresa'::text,'admin'::text])
      and exists (
        select 1 from public.candidate_profiles cp
        where cp.profile_id = skill_evidence.candidate_id
          and cp.searchable
      )
      and exists (
        select 1 from public.company_members cm
        where cm.user_id = (select auth.uid())
          and cm.member_role = any (array['owner'::text,'recruiter'::text,'viewer'::text])
      )
    )
  );
alter policy evidence_reviewer_update on public.skill_evidence
  using (
    private.is_admin()
    or (
      (select current_setting('talentos.reviewing', true)) = '1'
      and exists (
        select 1
        from public.applications a
        join public.jobs j on j.id = a.job_id
        join public.company_members cm on cm.company_id = j.company_id
        where a.candidate_id = skill_evidence.candidate_id
          and cm.user_id = (select auth.uid())
          and cm.member_role = any (array['owner'::text,'recruiter'::text])
      )
    )
  )
  with check (
    private.is_admin()
    or (
      (select current_setting('talentos.reviewing', true)) = '1'
      and exists (
        select 1
        from public.applications a
        join public.jobs j on j.id = a.job_id
        join public.company_members cm on cm.company_id = j.company_id
        where a.candidate_id = skill_evidence.candidate_id
          and cm.user_id = (select auth.uid())
          and cm.member_role = any (array['owner'::text,'recruiter'::text])
      )
    )
  );
alter policy evidence_delete on public.skill_evidence
  using (
    private.is_admin()
    or (
      candidate_id = (select auth.uid())
      and validation_status <> 'aprovada'
    )
  );

-- skill_assessments
drop policy if exists admin_full_access_skill_assessments on public.skill_assessments;
alter policy candidate_assessment_insert on public.skill_assessments
  with check (private.is_admin() or candidate_id = (select auth.uid()));
alter policy assessment_visibility on public.skill_assessments
  using (
    private.is_admin()
    or candidate_id = (select auth.uid())
    or exists (
      select 1
      from public.jobs j
      join public.company_members cm on cm.company_id = j.company_id
      where j.id = skill_assessments.job_id
        and cm.user_id = (select auth.uid())
    )
  );
drop policy if exists skill_assessments_admin_update on public.skill_assessments;
create policy skill_assessments_admin_update on public.skill_assessments
  for update to authenticated
  using (private.is_admin())
  with check (private.is_admin());
drop policy if exists skill_assessments_admin_delete on public.skill_assessments;
create policy skill_assessments_admin_delete on public.skill_assessments
  for delete to authenticated
  using (private.is_admin());

-- evidence_reviews
drop policy if exists admin_full_access_evidence_reviews on public.evidence_reviews;
alter policy evidence_reviews_insert on public.evidence_reviews
  with check (
    private.is_admin()
    or (
      (select current_setting('talentos.reviewing', true)) = '1'
      and reviewer_id = (select auth.uid())
      and exists (
        select 1
        from public.skill_evidence se
        join public.applications a on a.candidate_id = se.candidate_id
        join public.jobs j on j.id = a.job_id
        join public.company_members cm on cm.company_id = j.company_id
        where se.id = evidence_reviews.evidence_id
          and cm.user_id = (select auth.uid())
          and cm.member_role = any (array['owner'::text,'recruiter'::text])
      )
    )
  );
alter policy evidence_reviews_select on public.evidence_reviews
  using (
    private.is_admin()
    or reviewer_id = (select auth.uid())
    or exists (
      select 1
      from public.skill_evidence se
      join public.applications a on a.candidate_id = se.candidate_id
      join public.jobs j on j.id = a.job_id
      join public.company_members cm on cm.company_id = j.company_id
      where se.id = evidence_reviews.evidence_id
        and cm.user_id = (select auth.uid())
    )
  );
drop policy if exists evidence_reviews_admin_update on public.evidence_reviews;
create policy evidence_reviews_admin_update on public.evidence_reviews
  for update to authenticated
  using (private.is_admin())
  with check (private.is_admin());
drop policy if exists evidence_reviews_admin_delete on public.evidence_reviews;
create policy evidence_reviews_admin_delete on public.evidence_reviews
  for delete to authenticated
  using (private.is_admin());

-- training_recommendations
drop policy if exists admin_full_access_training_recommendations on public.training_recommendations;
alter policy training_generation_insert on public.training_recommendations
  with check (
    private.is_admin()
    or candidate_id = (select auth.uid())
    or exists (
      select 1
      from public.jobs j
      join public.company_members cm on cm.company_id = j.company_id
      where j.id = training_recommendations.job_id
        and cm.user_id = (select auth.uid())
        and cm.member_role = any (array['owner'::text,'recruiter'::text])
    )
  );
alter policy training_visibility on public.training_recommendations
  using (
    private.is_admin()
    or candidate_id = (select auth.uid())
    or exists (
      select 1
      from public.jobs j
      join public.company_members cm on cm.company_id = j.company_id
      where j.id = training_recommendations.job_id
        and cm.user_id = (select auth.uid())
    )
  );
alter policy training_update on public.training_recommendations
  using (
    private.is_admin()
    or candidate_id = (select auth.uid())
    or exists (
      select 1
      from public.jobs j
      join public.company_members cm on cm.company_id = j.company_id
      where j.id = training_recommendations.job_id
        and cm.user_id = (select auth.uid())
        and cm.member_role = any (array['owner'::text,'recruiter'::text])
    )
  )
  with check (
    private.is_admin()
    or candidate_id = (select auth.uid())
    or exists (
      select 1
      from public.jobs j
      join public.company_members cm on cm.company_id = j.company_id
      where j.id = training_recommendations.job_id
        and cm.user_id = (select auth.uid())
        and cm.member_role = any (array['owner'::text,'recruiter'::text])
    )
  );
drop policy if exists training_recommendations_admin_delete on public.training_recommendations;
create policy training_recommendations_admin_delete on public.training_recommendations
  for delete to authenticated
  using (private.is_admin());

-- employment_outcomes
drop policy if exists admin_full_access_employment_outcomes on public.employment_outcomes;
alter policy employment_outcomes_insert on public.employment_outcomes
  with check (
    private.is_admin()
    or (
      (select current_setting('talentos.outcome_write', true)) = '1'
      and exists (
        select 1 from public.company_members cm
        where cm.company_id = employment_outcomes.company_id
          and cm.user_id = (select auth.uid())
          and cm.member_role = any (array['owner'::text,'recruiter'::text])
      )
    )
  );
alter policy employment_outcomes_visibility on public.employment_outcomes
  using (
    private.is_admin()
    or exists (
      select 1 from public.company_members cm
      where cm.company_id = employment_outcomes.company_id
        and cm.user_id = (select auth.uid())
        and cm.member_role = any (array['owner'::text,'recruiter'::text,'viewer'::text])
    )
  );
alter policy employment_outcomes_update on public.employment_outcomes
  using (
    private.is_admin()
    or exists (
      select 1 from public.company_members cm
      where cm.company_id = employment_outcomes.company_id
        and cm.user_id = (select auth.uid())
        and cm.member_role = any (array['owner'::text,'recruiter'::text])
    )
  )
  with check (
    private.is_admin()
    or (
      (select current_setting('talentos.outcome_write', true)) = '1'
      and exists (
        select 1 from public.company_members cm
        where cm.company_id = employment_outcomes.company_id
          and cm.user_id = (select auth.uid())
          and cm.member_role = any (array['owner'::text,'recruiter'::text])
      )
    )
  );
drop policy if exists employment_outcomes_admin_delete on public.employment_outcomes;
create policy employment_outcomes_admin_delete on public.employment_outcomes
  for delete to authenticated
  using (private.is_admin());

-- employment_outcome_skill_signals
drop policy if exists admin_full_access_employment_outcome_skill_signals on public.employment_outcome_skill_signals;
alter policy outcome_skill_signals_write on public.employment_outcome_skill_signals
  with check (
    private.is_admin()
    or (
      (select current_setting('talentos.outcome_skill_write', true)) = '1'
      and exists (
        select 1
        from public.employment_outcomes eo
        join public.company_members cm on cm.company_id = eo.company_id
        where eo.id = employment_outcome_skill_signals.outcome_id
          and cm.user_id = (select auth.uid())
          and cm.member_role = any (array['owner'::text,'recruiter'::text])
      )
    )
  );
alter policy outcome_skill_signals_visibility on public.employment_outcome_skill_signals
  using (
    private.is_admin()
    or exists (
      select 1
      from public.employment_outcomes eo
      join public.company_members cm on cm.company_id = eo.company_id
      where eo.id = employment_outcome_skill_signals.outcome_id
        and cm.user_id = (select auth.uid())
        and cm.member_role = any (array['owner'::text,'recruiter'::text,'viewer'::text])
    )
  );
alter policy outcome_skill_signals_update on public.employment_outcome_skill_signals
  using (
    private.is_admin()
    or exists (
      select 1
      from public.employment_outcomes eo
      join public.company_members cm on cm.company_id = eo.company_id
      where eo.id = employment_outcome_skill_signals.outcome_id
        and cm.user_id = (select auth.uid())
        and cm.member_role = any (array['owner'::text,'recruiter'::text])
    )
  )
  with check (
    private.is_admin()
    or (
      (select current_setting('talentos.outcome_skill_write', true)) = '1'
      and exists (
        select 1
        from public.employment_outcomes eo
        join public.company_members cm on cm.company_id = eo.company_id
        where eo.id = employment_outcome_skill_signals.outcome_id
          and cm.user_id = (select auth.uid())
          and cm.member_role = any (array['owner'::text,'recruiter'::text])
      )
    )
  );
drop policy if exists employment_outcome_skill_signals_admin_delete on public.employment_outcome_skill_signals;
create policy employment_outcome_skill_signals_admin_delete on public.employment_outcome_skill_signals
  for delete to authenticated
  using (private.is_admin());
