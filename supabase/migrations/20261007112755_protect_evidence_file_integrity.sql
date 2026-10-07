-- Evidence is versioned by uploading a NEW object and submitting a NEW pending
-- record. Never replace bytes underneath a review (including a pending review).
-- Restrictive policies remain effective even if another permissive policy is added.
create policy skill_evidence_objects_immutable
on storage.objects as restrictive for update to authenticated
using (bucket_id <> 'skill-evidence')
with check (bucket_id <> 'skill-evidence');

-- RLS on skill_evidence must not hide a reference from the storage guard.
-- Only disclose whether the caller's own path can be cleaned up, never another
-- candidate's documents. This private helper is not exposed through PostgREST.
create or replace function private.evidence_object_is_unreferenced(p_name text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or split_part(p_name, '/', 1) is distinct from auth.uid()::text then
    return false;
  end if;
  return not exists (
    select 1 from public.skill_evidence e where e.storage_path = p_name
  );
end;
$$;
revoke all on function private.evidence_object_is_unreferenced(text) from public, anon;
grant execute on function private.evidence_object_is_unreferenced(text) to authenticated;

-- A dangling historical/privileged-deletion reference must not let a candidate
-- recreate different bytes at a path that still carries an approval.
create policy skill_evidence_objects_new_path_guard
on storage.objects as restrictive for insert to authenticated
with check (
  bucket_id <> 'skill-evidence'
  or private.evidence_object_is_unreferenced(name)
);

-- Allow cleanup of a failed submission. Referenced objects remain immutable;
-- pending/rejected evidence can first be removed under the existing table RLS.
create policy skill_evidence_objects_referenced_delete_guard
on storage.objects as restrictive for delete to authenticated
using (
  bucket_id <> 'skill-evidence'
  or private.evidence_object_is_unreferenced(name)
);

-- A reviewer can change the review, never the payload to which it applies.
-- Also reject foreign/nonexistent paths and approvals of a missing object.
-- Lock the object until submission/review commits so concurrent deletion cannot
-- complete while the existence check and approval are in progress.
create or replace function private.enforce_evidence_file_integrity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and (old.storage_path is not null or new.storage_path is not null) then
    if row(new.candidate_id, new.skill_id, new.evidence_type, new.title,
           new.issuer, new.expires_at, new.score, new.notes, new.storage_path,
           new.file_name, new.mime_type, new.file_size, new.file_hash)
       is distinct from
       row(old.candidate_id, old.skill_id, old.evidence_type, old.title,
           old.issuer, old.expires_at, old.score, old.notes, old.storage_path,
           old.file_name, old.mime_type, old.file_size, old.file_hash) then
      raise exception 'Envie um novo comprovante para alterar o arquivo ou seus dados. A nova versão precisa de revisão.'
        using errcode = '23514';
    end if;
  end if;

  if new.storage_path is not null then
    if auth.uid() is null
       or split_part(new.storage_path, '/', 1) is distinct from new.candidate_id::text then
      raise exception 'O arquivo deve pertencer ao candidato do comprovante.' using errcode = '23514';
    end if;
    if tg_op = 'INSERT' or new.validation_status = 'aprovada' or new.verified then
      perform 1 from storage.objects o
      where o.bucket_id = 'skill-evidence' and o.name = new.storage_path
      for share;
      if not found then
        raise exception 'Arquivo do comprovante não encontrado. Envie uma nova versão.' using errcode = '23514';
      end if;
    end if;
  end if;
  return new;
end;
$$;
revoke all on function private.enforce_evidence_file_integrity() from public, anon, authenticated;
create trigger protect_evidence_file_integrity
before insert or update on public.skill_evidence
for each row execute function private.enforce_evidence_file_integrity();
