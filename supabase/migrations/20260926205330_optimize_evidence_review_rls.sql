-- Optimize human evidence review RLS policies.
create index if not exists idx_evidence_reviews_reviewer
  on public.evidence_reviews(reviewer_id);

drop policy if exists evidence_reviewer_update on public.skill_evidence;
create policy evidence_reviewer_update on public.skill_evidence
for update to authenticated
using (
  (select current_setting('talentos.reviewing',true))='1'
  and exists (
    select 1 from public.applications a
    join public.jobs j on j.id=a.job_id
    join public.company_members cm on cm.company_id=j.company_id
    where a.candidate_id=skill_evidence.candidate_id
      and cm.user_id=(select auth.uid())
      and cm.member_role in ('owner','recruiter')
  )
)
with check (
  (select current_setting('talentos.reviewing',true))='1'
  and exists (
    select 1 from public.applications a
    join public.jobs j on j.id=a.job_id
    join public.company_members cm on cm.company_id=j.company_id
    where a.candidate_id=skill_evidence.candidate_id
      and cm.user_id=(select auth.uid())
      and cm.member_role in ('owner','recruiter')
  )
);

drop policy if exists evidence_reviews_insert on public.evidence_reviews;
create policy evidence_reviews_insert on public.evidence_reviews
for insert to authenticated
with check (
  (select current_setting('talentos.reviewing',true))='1'
  and reviewer_id=(select auth.uid())
  and exists (
    select 1 from public.skill_evidence se
    join public.applications a on a.candidate_id=se.candidate_id
    join public.jobs j on j.id=a.job_id
    join public.company_members cm on cm.company_id=j.company_id
    where se.id=evidence_reviews.evidence_id
      and cm.user_id=(select auth.uid())
      and cm.member_role in ('owner','recruiter')
  )
);