-- TalentOS Industrial: recruitment operations foundation
-- Saved jobs, alerts, messaging, interviews, structured scorecards,
-- talent pools, offers and public job slugs.

create table if not exists public.saved_jobs (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.candidate_profiles(profile_id) on delete cascade,
  job_id uuid not null references public.jobs(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(candidate_id, job_id)
);

create table if not exists public.job_alerts (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.candidate_profiles(profile_id) on delete cascade,
  name text not null,
  cargo text,
  skill text,
  city text,
  min_salary numeric(12,2),
  max_salary numeric(12,2),
  shift text,
  work_model text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.applications add column if not exists source text;
alter table public.applications add column if not exists source_detail text;

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.applications(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check(length(trim(body)) between 1 and 5000),
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.interviews (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.applications(id) on delete cascade,
  scheduled_at timestamptz not null,
  duration_minutes smallint not null default 45 check(duration_minutes between 15 and 240),
  mode text not null default 'online' check(mode in ('online','presencial')),
  location text,
  meeting_url text,
  interviewer_id uuid references public.profiles(id) on delete set null,
  status text not null default 'agendada' check(status in ('agendada','confirmada','cancelada','realizada')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.interview_scorecards (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.applications(id) on delete cascade,
  interviewer_id uuid not null references public.profiles(id) on delete cascade,
  competency text not null,
  rating smallint not null check(rating between 1 and 5),
  evidence_note text,
  created_at timestamptz not null default now(),
  unique(application_id, interviewer_id, competency)
);

create table if not exists public.talent_pools (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  name text not null,
  description text,
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now()
);

create table if not exists public.talent_pool_members (
  pool_id uuid not null references public.talent_pools(id) on delete cascade,
  candidate_id uuid not null references public.candidate_profiles(profile_id) on delete cascade,
  notes text,
  created_at timestamptz not null default now(),
  primary key(pool_id, candidate_id)
);

create table if not exists public.offers (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null unique references public.applications(id) on delete cascade,
  salary numeric(12,2),
  start_date date,
  message text,
  status text not null default 'enviada' check(status in ('enviada','aceita','recusada','cancelada')),
  created_by uuid not null references public.profiles(id) on delete restrict,
  responded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.jobs add column if not exists public_slug text;
update public.jobs
set public_slug = trim(both '-' from lower(regexp_replace(coalesce(title,'vaga') || '-' || substring(id::text,1,8),'[^a-zA-Z0-9]+','-','g')))
where public_slug is null;

create or replace function public.set_job_public_slug()
returns trigger language plpgsql set search_path=public
as $$
begin
  if new.public_slug is null or trim(new.public_slug)='' then
    new.public_slug := trim(both '-' from lower(regexp_replace(coalesce(new.title,'vaga') || '-' || substring(new.id::text,1,8),'[^a-zA-Z0-9]+','-','g')));
  end if;
  return new;
end;
$$;

drop trigger if exists jobs_public_slug on public.jobs;
create trigger jobs_public_slug
before insert or update of title, public_slug on public.jobs
for each row execute procedure public.set_job_public_slug();

create unique index if not exists jobs_public_slug_idx on public.jobs(public_slug) where public_slug is not null;
create index if not exists saved_jobs_candidate_idx on public.saved_jobs(candidate_id,created_at desc);
create index if not exists saved_jobs_job_idx on public.saved_jobs(job_id);
create index if not exists job_alerts_candidate_active_idx on public.job_alerts(candidate_id,active);
create index if not exists messages_application_created_idx on public.messages(application_id,created_at);
create index if not exists interviews_application_scheduled_idx on public.interviews(application_id,scheduled_at);
create index if not exists scorecards_application_idx on public.interview_scorecards(application_id);
create index if not exists talent_pool_company_idx on public.talent_pools(company_id);
create index if not exists talent_pool_members_candidate_idx on public.talent_pool_members(candidate_id);

alter table public.saved_jobs enable row level security;
alter table public.job_alerts enable row level security;
alter table public.messages enable row level security;
alter table public.interviews enable row level security;
alter table public.interview_scorecards enable row level security;
alter table public.talent_pools enable row level security;
alter table public.talent_pool_members enable row level security;
alter table public.offers enable row level security;

drop policy if exists saved_jobs_select on public.saved_jobs;
drop policy if exists saved_jobs_insert on public.saved_jobs;
drop policy if exists saved_jobs_delete on public.saved_jobs;
create policy saved_jobs_select on public.saved_jobs for select to authenticated using(candidate_id=(select auth.uid()));
create policy saved_jobs_insert on public.saved_jobs for insert to authenticated with check(candidate_id=(select auth.uid()));
create policy saved_jobs_delete on public.saved_jobs for delete to authenticated using(candidate_id=(select auth.uid()));

drop policy if exists job_alerts_select on public.job_alerts;
drop policy if exists job_alerts_insert on public.job_alerts;
drop policy if exists job_alerts_update on public.job_alerts;
drop policy if exists job_alerts_delete on public.job_alerts;
create policy job_alerts_select on public.job_alerts for select to authenticated using(candidate_id=(select auth.uid()));
create policy job_alerts_insert on public.job_alerts for insert to authenticated with check(candidate_id=(select auth.uid()));
create policy job_alerts_update on public.job_alerts for update to authenticated using(candidate_id=(select auth.uid())) with check(candidate_id=(select auth.uid()));
create policy job_alerts_delete on public.job_alerts for delete to authenticated using(candidate_id=(select auth.uid()));

drop policy if exists messages_select on public.messages;
drop policy if exists messages_insert on public.messages;
drop policy if exists messages_update on public.messages;
create policy messages_select on public.messages for select to authenticated using(
  sender_id=(select auth.uid()) or recipient_id=(select auth.uid())
  or exists(select 1 from public.applications a join public.jobs j on j.id=a.job_id join public.company_members cm on cm.company_id=j.company_id where a.id=application_id and cm.user_id=(select auth.uid()))
);
create policy messages_insert on public.messages for insert to authenticated
with check(
  sender_id=(select auth.uid()) and (
    (
      exists(select 1 from public.applications a where a.id=application_id and a.candidate_id=(select auth.uid()))
      and exists(
        select 1 from public.applications a join public.jobs j on j.id=a.job_id
        join public.company_members cm on cm.company_id=j.company_id
        where a.id=application_id and cm.user_id=recipient_id and cm.member_role in ('owner','recruiter','viewer')
      )
    )
    or (
      exists(select 1 from public.applications a join public.jobs j on j.id=a.job_id
        join public.company_members cm on cm.company_id=j.company_id
        where a.id=application_id and cm.user_id=(select auth.uid()) and cm.member_role in ('owner','recruiter'))
      and exists(select 1 from public.applications a where a.id=application_id and recipient_id=a.candidate_id)
    )
  )
);

drop policy if exists interviews_select on public.interviews;
drop policy if exists interviews_insert on public.interviews;
drop policy if exists interviews_update on public.interviews;
create policy interviews_select on public.interviews for select to authenticated using(
  exists(select 1 from public.applications a where a.id=application_id and (
    a.candidate_id=(select auth.uid())
    or exists(select 1 from public.jobs j join public.company_members cm on cm.company_id=j.company_id where j.id=a.job_id and cm.user_id=(select auth.uid()))
  ))
);
create policy interviews_insert on public.interviews for insert to authenticated with check(
  exists(select 1 from public.applications a join public.jobs j on j.id=a.job_id join public.company_members cm on cm.company_id=j.company_id where a.id=application_id and cm.user_id=(select auth.uid()) and cm.member_role in ('owner','recruiter'))
);
create policy interviews_update on public.interviews for update to authenticated
using(exists(select 1 from public.applications a join public.jobs j on j.id=a.job_id join public.company_members cm on cm.company_id=j.company_id where a.id=application_id and cm.user_id=(select auth.uid()) and cm.member_role in ('owner','recruiter')))
with check(exists(select 1 from public.applications a join public.jobs j on j.id=a.job_id join public.company_members cm on cm.company_id=j.company_id where a.id=application_id and cm.user_id=(select auth.uid()) and cm.member_role in ('owner','recruiter')));

drop policy if exists scorecards_select on public.interview_scorecards;
drop policy if exists scorecards_insert on public.interview_scorecards;
drop policy if exists scorecards_update on public.interview_scorecards;
create policy scorecards_select on public.interview_scorecards for select to authenticated
using(exists(select 1 from public.applications a join public.jobs j on j.id=a.job_id join public.company_members cm on cm.company_id=j.company_id where a.id=application_id and cm.user_id=(select auth.uid())));
create policy scorecards_insert on public.interview_scorecards for insert to authenticated
with check(interviewer_id=(select auth.uid()) and exists(select 1 from public.applications a join public.jobs j on j.id=a.job_id join public.company_members cm on cm.company_id=j.company_id where a.id=application_id and cm.user_id=(select auth.uid()) and cm.member_role in ('owner','recruiter')));
create policy scorecards_update on public.interview_scorecards for update to authenticated
using(interviewer_id=(select auth.uid())) with check(interviewer_id=(select auth.uid()));

drop policy if exists talent_pools_select on public.talent_pools;
drop policy if exists talent_pools_insert on public.talent_pools;
drop policy if exists talent_pools_update on public.talent_pools;
drop policy if exists talent_pools_delete on public.talent_pools;
create policy talent_pools_select on public.talent_pools for select to authenticated using(exists(select 1 from public.company_members cm where cm.company_id=company_id and cm.user_id=(select auth.uid())));
create policy talent_pools_insert on public.talent_pools for insert to authenticated with check(created_by=(select auth.uid()) and exists(select 1 from public.company_members cm where cm.company_id=company_id and cm.user_id=(select auth.uid()) and cm.member_role in ('owner','recruiter')));
create policy talent_pools_update on public.talent_pools for update to authenticated using(exists(select 1 from public.company_members cm where cm.company_id=company_id and cm.user_id=(select auth.uid()) and cm.member_role in ('owner','recruiter'))) with check(exists(select 1 from public.company_members cm where cm.company_id=company_id and cm.user_id=(select auth.uid()) and cm.member_role in ('owner','recruiter')));
create policy talent_pools_delete on public.talent_pools for delete to authenticated using(exists(select 1 from public.company_members cm where cm.company_id=company_id and cm.user_id=(select auth.uid()) and cm.member_role in ('owner','recruiter')));

drop policy if exists talent_pool_members_select on public.talent_pool_members;
drop policy if exists talent_pool_members_insert on public.talent_pool_members;
drop policy if exists talent_pool_members_delete on public.talent_pool_members;
create policy talent_pool_members_select on public.talent_pool_members for select to authenticated using(exists(select 1 from public.talent_pools p join public.company_members cm on cm.company_id=p.company_id where p.id=pool_id and cm.user_id=(select auth.uid())));
create policy talent_pool_members_insert on public.talent_pool_members for insert to authenticated with check(exists(select 1 from public.talent_pools p join public.company_members cm on cm.company_id=p.company_id where p.id=pool_id and cm.user_id=(select auth.uid()) and cm.member_role in ('owner','recruiter')));
create policy talent_pool_members_delete on public.talent_pool_members for delete to authenticated using(exists(select 1 from public.talent_pools p join public.company_members cm on cm.company_id=p.company_id where p.id=pool_id and cm.user_id=(select auth.uid()) and cm.member_role in ('owner','recruiter')));

drop policy if exists offers_select on public.offers;
drop policy if exists offers_insert on public.offers;
drop policy if exists offers_update on public.offers;
create policy offers_select on public.offers for select to authenticated using(
  exists(select 1 from public.applications a where a.id=application_id and (
    a.candidate_id=(select auth.uid())
    or exists(select 1 from public.jobs j join public.company_members cm on cm.company_id=j.company_id where j.id=a.job_id and cm.user_id=(select auth.uid()))
  ))
);
create policy offers_insert on public.offers for insert to authenticated with check(
  created_by=(select auth.uid()) and exists(select 1 from public.applications a join public.jobs j on j.id=a.job_id join public.company_members cm on cm.company_id=j.company_id where a.id=application_id and cm.user_id=(select auth.uid()) and cm.member_role in ('owner','recruiter'))
);
create policy offers_update on public.offers for update to authenticated
using(created_by=(select auth.uid()) or exists(select 1 from public.applications a where a.id=application_id and a.candidate_id=(select auth.uid())))
with check(created_by=(select auth.uid()) or exists(select 1 from public.applications a where a.id=application_id and a.candidate_id=(select auth.uid())));

grant select,insert,delete on public.saved_jobs to authenticated;
grant select,insert,update,delete on public.job_alerts to authenticated;
grant select,insert,update on public.messages to authenticated;
grant select,insert,update on public.interviews to authenticated;
grant select,insert,update on public.interview_scorecards to authenticated;
grant select,insert,update,delete on public.talent_pools to authenticated;
grant select,insert,delete on public.talent_pool_members to authenticated;
grant select,insert,update on public.offers to authenticated;

create index if not exists job_alerts_candidate_filter_idx on public.job_alerts(candidate_id,active,city,shift,work_model);
