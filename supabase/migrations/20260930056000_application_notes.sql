-- TalentOS Industrial: internal collaboration notes
create table if not exists public.application_notes (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.applications(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check(length(trim(body)) between 1 and 3000),
  created_at timestamptz not null default now()
);
create index if not exists application_notes_app_created_idx on public.application_notes(application_id,created_at desc);
alter table public.application_notes enable row level security;

create policy application_notes_select on public.application_notes
for select to authenticated using(
  exists(
    select 1 from public.applications a
    join public.jobs j on j.id=a.job_id
    join public.company_members cm on cm.company_id=j.company_id
    where a.id=application_id and cm.user_id=(select auth.uid())
      and cm.member_role in ('owner','recruiter','viewer')
  )
);

create policy application_notes_insert on public.application_notes
for insert to authenticated with check(
  author_id=(select auth.uid()) and exists(
    select 1 from public.applications a
    join public.jobs j on j.id=a.job_id
    join public.company_members cm on cm.company_id=j.company_id
    where a.id=application_id and cm.user_id=(select auth.uid())
      and cm.member_role in ('owner','recruiter')
  )
);

create policy application_notes_delete on public.application_notes
for delete to authenticated using(author_id=(select auth.uid()));

grant select,insert,delete on public.application_notes to authenticated;
