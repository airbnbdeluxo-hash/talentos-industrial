create table if not exists public.candidate_resumes (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.candidate_profiles(profile_id) on delete cascade,
  storage_path text not null unique,
  file_name text not null,
  mime_type text not null,
  file_size bigint not null check (file_size > 0 and file_size <= 10485760),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(candidate_id)
);

alter table public.candidate_resumes enable row level security;

drop policy if exists "candidate_resumes_self_select" on public.candidate_resumes;
create policy "candidate_resumes_self_select" on public.candidate_resumes
for select to authenticated using ((select auth.uid()) = candidate_id);

drop policy if exists "candidate_resumes_self_insert" on public.candidate_resumes;
create policy "candidate_resumes_self_insert" on public.candidate_resumes
for insert to authenticated with check ((select auth.uid()) = candidate_id);

drop policy if exists "candidate_resumes_self_update" on public.candidate_resumes;
create policy "candidate_resumes_self_update" on public.candidate_resumes
for update to authenticated
using ((select auth.uid()) = candidate_id)
with check ((select auth.uid()) = candidate_id);

drop policy if exists "candidate_resumes_self_delete" on public.candidate_resumes;
create policy "candidate_resumes_self_delete" on public.candidate_resumes
for delete to authenticated using ((select auth.uid()) = candidate_id);

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values (
  'candidate-resumes','candidate-resumes',false,10485760,
  array['application/pdf','application/vnd.openxmlformats-officedocument.wordprocessingml.document']
)
on conflict (id) do update set
  public=false,
  file_size_limit=10485760,
  allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "candidate_resumes_storage_insert" on storage.objects;
create policy "candidate_resumes_storage_insert" on storage.objects
for insert to authenticated
with check (
  bucket_id='candidate-resumes'
  and (storage.foldername(name))[1]=(select auth.uid())::text
);

drop policy if exists "candidate_resumes_storage_select" on storage.objects;
create policy "candidate_resumes_storage_select" on storage.objects
for select to authenticated
using (
  bucket_id='candidate-resumes'
  and (storage.foldername(name))[1]=(select auth.uid())::text
);

drop policy if exists "candidate_resumes_storage_update" on storage.objects;
create policy "candidate_resumes_storage_update" on storage.objects
for update to authenticated
using (
  bucket_id='candidate-resumes'
  and (storage.foldername(name))[1]=(select auth.uid())::text
)
with check (
  bucket_id='candidate-resumes'
  and (storage.foldername(name))[1]=(select auth.uid())::text
);

drop policy if exists "candidate_resumes_storage_delete" on storage.objects;
create policy "candidate_resumes_storage_delete" on storage.objects
for delete to authenticated
using (
  bucket_id='candidate-resumes'
  and (storage.foldername(name))[1]=(select auth.uid())::text
);