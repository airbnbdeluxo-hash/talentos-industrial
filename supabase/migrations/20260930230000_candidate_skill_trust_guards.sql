-- Keep candidate self-assessment editable without allowing self-verification
-- or rewriting trusted provenance.

drop policy if exists candidate_skills_insert on public.candidate_skills;
create policy candidate_skills_insert
on public.candidate_skills
for insert
to authenticated
with check (
  private.is_admin()
  or (
    candidate_id = (select auth.uid())
    and verified = false
    and proficiency between 1 and 5
    and years_experience between 0 and 100
    and source_type in ('manual','curriculo')
    and (
      (source_type = 'manual'
        and source_resume_id is null
        and source_confidence is null
        and source_excerpt is null)
      or
      (source_type = 'curriculo'
        and source_resume_id is not null
        and source_confidence between 0 and 1
        and exists (
          select 1
          from public.candidate_resumes cr
          where cr.id = candidate_skills.source_resume_id
            and cr.candidate_id = (select auth.uid())
        ))
    )
  )
);

create or replace function private.enforce_candidate_skill_self_trust()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- Direct authenticated/self-service writes may edit self-assessed level/years,
  -- but cannot manufacture verification or rewrite provenance. SECURITY DEFINER
  -- review/outcome functions run as their owner and are not constrained here.
  if current_user = 'authenticated'
     and (select auth.uid()) = old.candidate_id
     and not coalesce(private.is_admin(), false)
  then
    if new.candidate_id is distinct from old.candidate_id
       or new.skill_id is distinct from old.skill_id then
      raise exception 'candidate skill identity is immutable';
    end if;

    if new.verified is distinct from old.verified then
      raise exception 'candidate cannot change verification state';
    end if;

    if new.source_type is distinct from old.source_type
       or new.source_confidence is distinct from old.source_confidence
       or new.source_excerpt is distinct from old.source_excerpt
       or new.source_resume_id is distinct from old.source_resume_id then
      raise exception 'candidate skill provenance is immutable';
    end if;

    if old.verified and new.proficiency is distinct from old.proficiency then
      raise exception 'verified proficiency cannot be self-edited';
    end if;

    if new.proficiency not between 1 and 5
       or new.years_experience not between 0 and 100 then
      raise exception 'candidate skill values are out of range';
    end if;
  end if;

  return new;
end;
$$;

revoke all on function private.enforce_candidate_skill_self_trust() from public, anon, authenticated;

drop trigger if exists candidate_skills_self_trust_guard on public.candidate_skills;
create trigger candidate_skills_self_trust_guard
before update on public.candidate_skills
for each row execute function private.enforce_candidate_skill_self_trust();
