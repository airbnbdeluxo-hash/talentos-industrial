-- Database enforcement: candidates may apply only to open job postings.
-- Preserves the existing admin exemption and applicant-identity check.
-- Must be reviewed and applied through the controlled release; DO NOT execute
-- against production as an ad-hoc change before the PR receives human approval.
alter policy applications_insert on public.applications
  to authenticated
  with check (
    private.is_admin()
    or (
      candidate_id = (select auth.uid())
      and exists (
        select 1
        from public.jobs as available_job
        where available_job.id = applications.job_id
          and available_job.status = 'aberta'
      )
    )
  );
