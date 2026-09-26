-- Challenge scoring is human-validated; keep useful indexes and do not expose scoring secrets.
create index if not exists idx_challenge_attempts_challenge
  on public.challenge_attempts(challenge_id);

create index if not exists idx_challenge_attempts_job
  on public.challenge_attempts(job_id);

create index if not exists idx_skill_assessments_challenge
  on public.skill_assessments(challenge_id);