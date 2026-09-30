-- TalentOS Industrial: candidate weekly availability for interview scheduling
create table if not exists public.candidate_availability (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.candidate_profiles(profile_id) on delete cascade,
  weekday smallint not null check(weekday between 0 and 6),
  start_time time not null,
  end_time time not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(candidate_id,weekday,start_time,end_time)
);
create index if not exists candidate_availability_candidate_day_idx on public.candidate_availability(candidate_id,weekday,active);
alter table public.candidate_availability enable row level security;
create policy candidate_availability_select on public.candidate_availability
for select to authenticated using(
  candidate_id=(select auth.uid())
  or exists(
    select 1 from public.applications a
    join public.jobs j on j.id=a.job_id
    join public.company_members cm on cm.company_id=j.company_id
    where a.candidate_id=candidate_availability.candidate_id
      and cm.user_id=(select auth.uid())
  )
);
create policy candidate_availability_insert on public.candidate_availability
for insert to authenticated with check(candidate_id=(select auth.uid()));
create policy candidate_availability_update on public.candidate_availability
for update to authenticated using(candidate_id=(select auth.uid())) with check(candidate_id=(select auth.uid()));
create policy candidate_availability_delete on public.candidate_availability
for delete to authenticated using(candidate_id=(select auth.uid()));
grant select,insert,update,delete on public.candidate_availability to authenticated;
