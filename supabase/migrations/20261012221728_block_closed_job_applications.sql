-- Enforce the candidate application lifecycle at the database boundary.
-- A candidate can create an application only for an open posting, at the
-- initial status ('novo'), without setting employer-only rejection outcomes.
-- Administrative exception is preserved. The existing application identity
-- guard and company status transitions are unaffected.
-- Reviewed migration only: do not apply prior to approval of PR #89.
alter policy applications_insert on public.applications
  to authenticated
  with check (
    private.is_admin()
    or (
      candidate_id = (select auth.uid())
      and status = 'novo'
      and rejection_reason_code is null
      and rejection_reason_note is null
      and exists (
        select 1
        from public.jobs as available_job
        where available_job.id = applications.job_id
          and available_job.status = 'aberta'
      )
    )
  );
