-- TalentOS Industrial: engagement analytics and document trust signals
create table if not exists public.job_engagement_events (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  event_type text not null check(event_type in ('visualizacao','inicio_candidatura')),
  session_id text not null check(length(session_id) between 16 and 64),
  candidate_id uuid references public.candidate_profiles(profile_id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists job_engagement_job_event_idx on public.job_engagement_events(job_id,event_type,created_at desc);
alter table public.job_engagement_events enable row level security;
create policy engagement_insert_public on public.job_engagement_events
for insert to anon,authenticated
with check(
  length(session_id) between 16 and 64
  and exists(select 1 from public.jobs j where j.id=job_id and j.status='aberta')
);
create policy engagement_select_company on public.job_engagement_events
for select to authenticated
using(
  exists(
    select 1 from public.jobs j
    join public.company_members cm on cm.company_id=j.company_id
    where j.id=job_id and cm.user_id=(select auth.uid())
  )
);
grant insert on public.job_engagement_events to anon,authenticated;
grant select on public.job_engagement_events to authenticated;

alter table public.skill_evidence add column if not exists file_hash text;
alter table public.skill_evidence add column if not exists integrity_status text not null default 'normal';
create index if not exists skill_evidence_file_hash_idx on public.skill_evidence(file_hash) where file_hash is not null;
