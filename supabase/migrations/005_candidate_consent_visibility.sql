alter table public.candidate_profiles add column if not exists visibility_consent_at timestamptz;
alter table public.candidate_profiles add column if not exists consent_version text;
update public.candidate_profiles set visibility_consent_at=coalesce(visibility_consent_at,now()) where searchable=true and visibility_consent_at is null;
drop policy if exists "candidate_self" on public.candidate_profiles;
create policy "candidate_self" on public.candidate_profiles for select to authenticated
using(profile_id=(select auth.uid()) or (searchable and exists(select 1 from public.company_members cm where cm.user_id=(select auth.uid()) and cm.member_role in ('owner','recruiter','viewer'))));
drop policy if exists "candidate_skills_access" on public.candidate_skills;
create policy "candidate_skills_access" on public.candidate_skills for select to authenticated
using(candidate_id=(select auth.uid()) or (exists(select 1 from public.candidate_profiles cp where cp.profile_id=candidate_id and cp.searchable) and exists(select 1 from public.company_members cm where cm.user_id=(select auth.uid()) and cm.member_role in ('owner','recruiter','viewer'))));
drop policy if exists "evidence_access" on public.skill_evidence;
create policy "evidence_access" on public.skill_evidence for select to authenticated
using(candidate_id=(select auth.uid()) or (exists(select 1 from public.candidate_profiles cp where cp.profile_id=candidate_id and cp.searchable) and exists(select 1 from public.company_members cm where cm.user_id=(select auth.uid()) and cm.member_role in ('owner','recruiter','viewer'))));
