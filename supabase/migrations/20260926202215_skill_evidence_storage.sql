-- TalentOS evidence files in private Supabase Storage
alter table public.skill_evidence
  add column if not exists storage_path text,
  add column if not exists file_name text,
  add column if not exists mime_type text,
  add column if not exists file_size bigint;

create index if not exists idx_skill_evidence_storage_path
  on public.skill_evidence(storage_path)
  where storage_path is not null;

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values (
  'skill-evidence','skill-evidence',false,10485760,
  array['application/pdf','image/jpeg','image/png','image/webp','text/plain']
)
on conflict (id) do update
set public=false,file_size_limit=10485760,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists skill_evidence_storage_insert on storage.objects;
create policy skill_evidence_storage_insert on storage.objects
for insert to authenticated
with check (
  bucket_id='skill-evidence'
  and (storage.foldername(name))[1]=(select auth.uid()::text)
);

drop policy if exists skill_evidence_storage_select on storage.objects;
create policy skill_evidence_storage_select on storage.objects
for select to authenticated
using (
  bucket_id='skill-evidence'
  and (
    (storage.foldername(name))[1]=(select auth.uid()::text)
    or exists (
      select 1
      from public.skill_evidence se
      join public.candidate_profiles cp on cp.profile_id=se.candidate_id
      where se.storage_path=storage.objects.name
        and cp.searchable
        and exists (
          select 1
          from public.company_members cm
          where cm.user_id=(select auth.uid())
            and cm.member_role in ('owner','recruiter','viewer')
        )
    )
  )
);

drop policy if exists skill_evidence_storage_update on storage.objects;
create policy skill_evidence_storage_update on storage.objects
for update to authenticated
using (
  bucket_id='skill-evidence'
  and (storage.foldername(name))[1]=(select auth.uid()::text)
)
with check (
  bucket_id='skill-evidence'
  and (storage.foldername(name))[1]=(select auth.uid()::text)
);

drop policy if exists skill_evidence_storage_delete on storage.objects;
create policy skill_evidence_storage_delete on storage.objects
for delete to authenticated
using (
  bucket_id='skill-evidence'
  and (storage.foldername(name))[1]=(select auth.uid()::text)
);