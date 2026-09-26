-- TalentOS Industrial: multi-tenant security + Auth bootstrap
alter table public.companies add column if not exists created_by uuid references public.profiles(id) on delete set null;
alter table public.candidate_profiles add column if not exists searchable boolean not null default true;

create table if not exists public.company_members (
  company_id uuid not null references public.companies(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  member_role text not null default 'recruiter' check(member_role in ('owner','recruiter','viewer')),
  created_at timestamptz not null default now(),
  primary key(company_id,user_id)
);

create index if not exists idx_company_members_user on public.company_members(user_id);
create index if not exists idx_companies_created_by on public.companies(created_by);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles(id, role, full_name, phone, city, state)
  values (
    new.id,
    case when (new.raw_user_meta_data ->> 'role') in ('empresa','candidato','admin')
      then (new.raw_user_meta_data ->> 'role')::public.app_role
      else 'candidato'::public.app_role end,
    coalesce(new.raw_user_meta_data ->> 'full_name', split_part(coalesce(new.email,''),'@',1), 'Novo usuário'),
    new.phone,
    new.raw_user_meta_data ->> 'city',
    coalesce(new.raw_user_meta_data ->> 'state','RS')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

alter table public.company_members enable row level security;

drop policy if exists "skills readable" on public.skills;
create policy "skills readable" on public.skills for select to anon, authenticated using (true);

-- Profiles
drop policy if exists "own profile" on public.profiles;
create policy "profiles own select" on public.profiles for select to authenticated using ((select auth.uid()) = id);
create policy "profiles own update" on public.profiles for update to authenticated
using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

-- Companies
drop policy if exists "companies member select" on public.companies;
create policy "companies member select" on public.companies for select to authenticated
using (
  created_by = (select auth.uid())
  or exists (select 1 from public.company_members cm where cm.company_id = id and cm.user_id = (select auth.uid()))
);
create policy "companies owner insert" on public.companies for insert to authenticated
with check (created_by = (select auth.uid()));
create policy "companies member update" on public.companies for update to authenticated
using (
  created_by = (select auth.uid())
  or exists (select 1 from public.company_members cm where cm.company_id = id and cm.user_id = (select auth.uid()) and cm.member_role in ('owner','recruiter'))
)
with check (
  created_by = (select auth.uid())
  or exists (select 1 from public.company_members cm where cm.company_id = id and cm.user_id = (select auth.uid()) and cm.member_role in ('owner','recruiter'))
);

-- Company membership
create policy "company members self insert" on public.company_members for insert to authenticated
with check (
  user_id = (select auth.uid())
  and exists (select 1 from public.companies c where c.id = company_id and c.created_by = (select auth.uid()))
);
create policy "company members own company select" on public.company_members for select to authenticated
using (
  user_id = (select auth.uid())
  or exists (select 1 from public.company_members cm2 where cm2.company_id = company_id and cm2.user_id = (select auth.uid()))
);

-- Jobs
drop policy if exists "jobs public when open" on public.jobs;
create policy "open jobs readable" on public.jobs for select to anon, authenticated using (
  status = 'aberta'
);
create policy "company members read jobs" on public.jobs for select to authenticated using (
  exists (select 1 from public.company_members cm where cm.company_id = jobs.company_id and cm.user_id = (select auth.uid()))
);
create policy "company members create jobs" on public.jobs for insert to authenticated
with check (
  exists (select 1 from public.company_members cm where cm.company_id = jobs.company_id and cm.user_id = (select auth.uid()) and cm.member_role in ('owner','recruiter'))
);
create policy "company members update jobs" on public.jobs for update to authenticated
using (exists (select 1 from public.company_members cm where cm.company_id = jobs.company_id and cm.user_id = (select auth.uid()) and cm.member_role in ('owner','recruiter')))
with check (exists (select 1 from public.company_members cm where cm.company_id = jobs.company_id and cm.user_id = (select auth.uid()) and cm.member_role in ('owner','recruiter')));

-- Candidate visibility
create policy "searchable candidates readable to companies" on public.candidate_profiles for select to authenticated
using (
  profile_id = (select auth.uid())
  or searchable
);
create policy "candidate can update own profile" on public.candidate_profiles for update to authenticated
using ((select auth.uid()) = profile_id) with check ((select auth.uid()) = profile_id);
create policy "candidate can insert own profile" on public.candidate_profiles for insert to authenticated
with check ((select auth.uid()) = profile_id);

create policy "candidate skills readable" on public.candidate_skills for select to authenticated
using (
  candidate_id = (select auth.uid())
  or exists (select 1 from public.candidate_profiles cp where cp.profile_id = candidate_id and cp.searchable)
);
create policy "candidate owns skills" on public.candidate_skills for insert to authenticated
with check ((select auth.uid()) = candidate_id);
create policy "candidate updates own skills" on public.candidate_skills for update to authenticated
using ((select auth.uid()) = candidate_id) with check ((select auth.uid()) = candidate_id);
create policy "candidate deletes own skills" on public.candidate_skills for delete to authenticated
using ((select auth.uid()) = candidate_id);

-- Job skills
create policy "job skills readable" on public.job_skills for select to anon, authenticated
using (exists (select 1 from public.jobs j where j.id = job_id and j.status='aberta') or exists (
  select 1 from public.jobs j join public.company_members cm on cm.company_id=j.company_id
  where j.id=job_id and cm.user_id=(select auth.uid())
));
create policy "company members create job skills" on public.job_skills for insert to authenticated
with check (exists (select 1 from public.jobs j join public.company_members cm on cm.company_id=j.company_id where j.id=job_id and cm.user_id=(select auth.uid()) and cm.member_role in ('owner','recruiter')));
create policy "company members update job skills" on public.job_skills for update to authenticated
using (exists (select 1 from public.jobs j join public.company_members cm on cm.company_id=j.company_id where j.id=job_id and cm.user_id=(select auth.uid()) and cm.member_role in ('owner','recruiter')))
with check (exists (select 1 from public.jobs j join public.company_members cm on cm.company_id=j.company_id where j.id=job_id and cm.user_id=(select auth.uid()) and cm.member_role in ('owner','recruiter')));

-- Matches
create policy "match readable by candidate or company" on public.matches for select to authenticated
using (
  candidate_id = (select auth.uid())
  or exists (select 1 from public.jobs j join public.company_members cm on cm.company_id=j.company_id where j.id=job_id and cm.user_id=(select auth.uid()))
);
create policy "company member inserts match" on public.matches for insert to authenticated
with check (exists (select 1 from public.jobs j join public.company_members cm on cm.company_id=j.company_id where j.id=job_id and cm.user_id=(select auth.uid()) and cm.member_role in ('owner','recruiter')));

-- Applications
create policy "application readable by parties" on public.applications for select to authenticated
using (
  candidate_id = (select auth.uid())
  or exists (select 1 from public.jobs j join public.company_members cm on cm.company_id=j.company_id where j.id=job_id and cm.user_id=(select auth.uid()))
);
create policy "candidate creates application" on public.applications for insert to authenticated
with check (candidate_id=(select auth.uid()));
create policy "parties update application" on public.applications for update to authenticated
using (
  candidate_id=(select auth.uid())
  or exists (select 1 from public.jobs j join public.company_members cm on cm.company_id=j.company_id where j.id=job_id and cm.user_id=(select auth.uid()) and cm.member_role in ('owner','recruiter'))
)
with check (
  candidate_id=(select auth.uid())
  or exists (select 1 from public.jobs j join public.company_members cm on cm.company_id=j.company_id where j.id=job_id and cm.user_id=(select auth.uid()) and cm.member_role in ('owner','recruiter'))
);

revoke all on table public.company_members from anon;
grant select, insert on public.company_members to authenticated;

-- Helpful indexes for RLS joins
create index if not exists idx_jobs_company on public.jobs(company_id);
create index if not exists idx_job_skills_job on public.job_skills(job_id);
create index if not exists idx_matches_candidate on public.matches(candidate_id);
create index if not exists idx_applications_candidate on public.applications(candidate_id);
