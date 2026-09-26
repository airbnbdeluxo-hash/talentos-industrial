-- TalentOS human evidence validation: auditable and role-restricted.
alter table public.skill_evidence
  add column if not exists validation_status text not null default 'pendente'
    check (validation_status in ('pendente','aprovada','reprovada')),
  add column if not exists reviewed_by uuid references public.profiles(id),
  add column if not exists reviewed_at timestamptz,
  add column if not exists review_note text;

create index if not exists idx_skill_evidence_validation
  on public.skill_evidence(candidate_id,validation_status);
create index if not exists idx_skill_evidence_reviewed_by
  on public.skill_evidence(reviewed_by)
  where reviewed_by is not null;

create table if not exists public.evidence_reviews(
  id uuid primary key default gen_random_uuid(),
  evidence_id uuid not null references public.skill_evidence(id) on delete cascade,
  reviewer_id uuid not null references public.profiles(id) on delete restrict,
  from_status text not null check(from_status in ('pendente','aprovada','reprovada')),
  to_status text not null check(to_status in ('pendente','aprovada','reprovada')),
  note text,
  created_at timestamptz not null default now()
);

create index if not exists idx_evidence_reviews_evidence_created
  on public.evidence_reviews(evidence_id,created_at desc);

alter table public.evidence_reviews enable row level security;

drop policy if exists evidence_reviews_select on public.evidence_reviews;
create policy evidence_reviews_select on public.evidence_reviews
for select to authenticated
using (
  reviewer_id=(select auth.uid())
  or exists (
    select 1
    from public.skill_evidence se
    join public.applications a on a.candidate_id=se.candidate_id
    join public.jobs j on j.id=a.job_id
    join public.company_members cm on cm.company_id=j.company_id
    where se.id=evidence_reviews.evidence_id
      and cm.user_id=(select auth.uid())
  )
);

drop policy if exists evidence_reviews_insert on public.evidence_reviews;
create policy evidence_reviews_insert on public.evidence_reviews
for insert to authenticated
with check (
  current_setting('talentos.reviewing',true)='1'
  and reviewer_id=(select auth.uid())
  and exists (
    select 1
    from public.skill_evidence se
    join public.applications a on a.candidate_id=se.candidate_id
    join public.jobs j on j.id=a.job_id
    join public.company_members cm on cm.company_id=j.company_id
    where se.id=evidence_reviews.evidence_id
      and cm.user_id=(select auth.uid())
      and cm.member_role in ('owner','recruiter')
  )
);

drop policy if exists evidence_update on public.skill_evidence;

drop policy if exists evidence_reviewer_update on public.skill_evidence;
create policy evidence_reviewer_update on public.skill_evidence
for update to authenticated
using (
  current_setting('talentos.reviewing',true)='1'
  and exists (
    select 1
    from public.applications a
    join public.jobs j on j.id=a.job_id
    join public.company_members cm on cm.company_id=j.company_id
    where a.candidate_id=skill_evidence.candidate_id
      and cm.user_id=(select auth.uid())
      and cm.member_role in ('owner','recruiter')
  )
)
with check (
  current_setting('talentos.reviewing',true)='1'
  and exists (
    select 1
    from public.applications a
    join public.jobs j on j.id=a.job_id
    join public.company_members cm on cm.company_id=j.company_id
    where a.candidate_id=skill_evidence.candidate_id
      and cm.user_id=(select auth.uid())
      and cm.member_role in ('owner','recruiter')
  )
);

drop policy if exists evidence_delete on public.skill_evidence;
create policy evidence_delete on public.skill_evidence
for delete to authenticated
using (
  candidate_id=(select auth.uid())
  and validation_status<>'aprovada'
);

create or replace function public.enforce_evidence_validation_state()
returns trigger
language plpgsql
security invoker
set search_path=public
as $$
begin
  if tg_op='INSERT' then
    new.validation_status='pendente';
    new.verified=false;
    new.verified_at=null;
    new.reviewed_by=null;
    new.reviewed_at=null;
    new.review_note=null;
    return new;
  end if;

  if tg_op='UPDATE' then
    if current_setting('talentos.reviewing',true)<>'1' then
      if new.candidate_id is distinct from old.candidate_id
         or new.skill_id is distinct from old.skill_id
         or new.evidence_type is distinct from old.evidence_type
         or new.title is distinct from old.title
         or new.issuer is distinct from old.issuer
         or new.expires_at is distinct from old.expires_at
         or new.score is distinct from old.score
         or new.notes is distinct from old.notes
         or new.storage_path is distinct from old.storage_path
         or new.file_name is distinct from old.file_name
         or new.mime_type is distinct from old.mime_type
         or new.file_size is distinct from old.file_size
         or new.validation_status is distinct from old.validation_status
         or new.verified is distinct from old.verified
         or new.verified_at is distinct from old.verified_at
         or new.reviewed_by is distinct from old.reviewed_by
         or new.reviewed_at is distinct from old.reviewed_at
         or new.review_note is distinct from old.review_note then
        raise exception 'evidence validation fields are protected';
      end if;
    end if;
    if new.validation_status='aprovada' and not new.verified then
      raise exception 'approved evidence must be verified';
    end if;
    if new.validation_status<>'aprovada' and new.verified then
      raise exception 'only approved evidence may be verified';
    end if;
    return new;
  end if;

  return new;
end;
$$;

drop trigger if exists enforce_evidence_validation_state on public.skill_evidence;
create trigger enforce_evidence_validation_state
before insert or update on public.skill_evidence
for each row execute function public.enforce_evidence_validation_state();

create or replace function public.review_skill_evidence(
  p_evidence_id uuid,
  p_status text,
  p_note text default null
)
returns public.skill_evidence
language plpgsql
security invoker
set search_path=public
as $$
declare
  v_old public.skill_evidence;
  v_new public.skill_evidence;
begin
  if p_status not in ('aprovada','reprovada') then
    raise exception 'invalid validation status';
  end if;

  perform set_config('talentos.reviewing','1',true);

  select se.* into v_old
  from public.skill_evidence se
  where se.id=p_evidence_id;

  if v_old.id is null then raise exception 'evidence not found'; end if;

  update public.skill_evidence se
  set validation_status=p_status,
      verified=(p_status='aprovada'),
      verified_at=case when p_status='aprovada' then now() else null end,
      reviewed_by=(select auth.uid()),
      reviewed_at=now(),
      review_note=nullif(trim(p_note),'')
  where se.id=p_evidence_id
  returning se.* into v_new;

  if not found then raise exception 'not authorized to review evidence'; end if;

  insert into public.evidence_reviews(
    evidence_id,reviewer_id,from_status,to_status,note
  ) values(
    p_evidence_id,(select auth.uid()),v_old.validation_status,p_status,nullif(trim(p_note),'')
  );

  update public.candidate_skills cs
  set verified=exists(
    select 1
    from public.skill_evidence se
    where se.candidate_id=cs.candidate_id
      and se.skill_id=cs.skill_id
      and se.validation_status='aprovada'
  )
  where cs.candidate_id=v_new.candidate_id
    and cs.skill_id=v_new.skill_id;

  return v_new;
end;
$$;

revoke all on function public.review_skill_evidence(uuid,text,text) from public,anon;
grant execute on function public.review_skill_evidence(uuid,text,text) to authenticated;
