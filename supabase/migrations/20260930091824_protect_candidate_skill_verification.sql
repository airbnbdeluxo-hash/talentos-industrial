create or replace function public.protect_candidate_skill_verification()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if coalesce((select private.is_admin()),false)
     or current_setting('talentos.reviewing', true)='1' then
    return new;
  end if;

  if tg_op='INSERT' then
    new.verified := false;
  elsif tg_op='UPDATE' then
    new.verified := old.verified;
  end if;

  return new;
end;
$$;

drop trigger if exists protect_candidate_skill_verification on public.candidate_skills;

create trigger protect_candidate_skill_verification
before insert or update on public.candidate_skills
for each row execute function public.protect_candidate_skill_verification();

revoke all on function public.protect_candidate_skill_verification() from public;
grant execute on function public.protect_candidate_skill_verification() to authenticated;
