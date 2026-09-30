-- TalentOS Industrial: structured interview guide
alter table public.jobs add column if not exists interview_questions jsonb not null default '[]'::jsonb;
create index if not exists jobs_interview_questions_gin_idx on public.jobs using gin(interview_questions);
