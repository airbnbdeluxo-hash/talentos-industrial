-- Storage policy regression only: synthetic metadata, no file bytes or real user IDs.
-- SQL is run in one transaction and always rolled back.
begin;
do $$ begin
  if not (select relrowsecurity from pg_class where oid='storage.objects'::regclass) then
    raise exception 'FAIL storage.objects RLS disabled';
  end if;
  if exists (select 1 from storage.buckets where id in ('candidate-resumes','skill-evidence') and (public or file_size_limit is distinct from 10485760)) then
    raise exception 'FAIL private bucket configuration';
  end if;
  if (select count(*) from storage.buckets where id in ('candidate-resumes','skill-evidence')) <> 2 then
    raise exception 'FAIL required buckets missing';
  end if;
  if not exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='skill_evidence_objects_immutable' and cmd='UPDATE' and permissive='RESTRICTIVE') then
    raise exception 'FAIL evidence UPDATE requires restrictive policy';
  end if;
  if not exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='skill_evidence_objects_referenced_delete_guard' and cmd='DELETE' and permissive='RESTRICTIVE') then
    raise exception 'FAIL evidence DELETE requires restrictive policy';
  end if;
end $$;

-- Only metadata rows exist; no object is uploaded to storage.
insert into storage.objects(id,bucket_id,name,owner_id) values
  ('c3500000-0000-4000-8000-000000000011','candidate-resumes','c3500000-0000-4000-8000-000000000001/private-qa-resume.txt','c3500000-0000-4000-8000-000000000001'),
  ('c3500000-0000-4000-8000-000000000012','skill-evidence','c3500000-0000-4000-8000-000000000001/private-qa-evidence.txt','c3500000-0000-4000-8000-000000000001');

set local role authenticated;
select set_config('request.jwt.claim.sub','c3500000-0000-4000-8000-000000000001',true);
do $$ declare affected integer; begin
  if (select count(*) from storage.objects where id in ('c3500000-0000-4000-8000-000000000011','c3500000-0000-4000-8000-000000000012')) <> 2 then
    raise exception 'FAIL owner cannot view own private objects';
  end if;
  update storage.objects set metadata='{"test":"tampered"}'::jsonb where id='c3500000-0000-4000-8000-000000000012';
  get diagnostics affected=row_count;
  if affected <> 0 then raise exception 'FAIL evidence owner can overwrite immutable object'; end if;
end $$;

select set_config('request.jwt.claim.sub','c3500000-0000-4000-8000-000000000002',true);
do $$ declare affected integer; begin
  if exists (select 1 from storage.objects where id in ('c3500000-0000-4000-8000-000000000011','c3500000-0000-4000-8000-000000000012')) then
    raise exception 'FAIL unrelated candidate can read private object';
  end if;
  update storage.objects set metadata='{"test":"cross-user"}'::jsonb where id='c3500000-0000-4000-8000-000000000011';
  get diagnostics affected=row_count;
  if affected <> 0 then raise exception 'FAIL unrelated candidate can update another resume'; end if;
end $$;

set local role anon;
do $$ begin
  if exists (select 1 from storage.objects where id in ('c3500000-0000-4000-8000-000000000011','c3500000-0000-4000-8000-000000000012')) then
    raise exception 'FAIL anonymous user can enumerate private objects';
  end if;
end $$;
rollback;
select 'PASS: buckets private, owner visibility, candidate isolation, anon isolation and immutable evidence; all fixture metadata rolled back' as result;
