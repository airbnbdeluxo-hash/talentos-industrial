-- Low-risk database advisor cleanup.
-- Cover foreign keys used by company invitation lifecycle and remove a redundant
-- permissive DELETE policy already subsumed by jobskills_delete.

create index if not exists company_invitations_invited_user_idx
  on public.company_invitations(invited_user_id)
  where invited_user_id is not null;

create index if not exists company_invitations_invited_by_idx
  on public.company_invitations(invited_by);

create index if not exists company_invitations_accepted_by_idx
  on public.company_invitations(accepted_by)
  where accepted_by is not null;

drop policy if exists job_skills_admin_delete on public.job_skills;
