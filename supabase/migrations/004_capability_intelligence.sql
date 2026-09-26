-- TalentOS V5: capability intelligence data model
create table if not exists public.skill_evidence (
  id uuid primary key default gen_random_uuid(), candidate_id uuid not null references public.candidate_profiles(profile_id) on delete cascade,
  skill_id uuid not null references public.skills(id) on delete cascade,
  evidence_type text not null check (evidence_type in ('certificado','avaliacao','experiencia','referencia','desafio')),
  title text not null, issuer text, verified boolean not null default false, verified_at timestamptz,
  expires_at timestamptz, score numeric(5,2), notes text, created_at timestamptz not null default now()
);
create index if not exists idx_skill_evidence_candidate on public.skill_evidence(candidate_id,skill_id);
create table if not exists public.skill_assessments (
  id uuid primary key default gen_random_uuid(), candidate_id uuid not null references public.candidate_profiles(profile_id) on delete cascade,
  job_id uuid references public.jobs(id) on delete set null, assessment_type text not null,
  score numeric(5,2), status text not null default 'pendente', completed_at timestamptz, created_at timestamptz not null default now()
);
create table if not exists public.training_recommendations (
  id uuid primary key default gen_random_uuid(), candidate_id uuid not null references public.candidate_profiles(profile_id) on delete cascade,
  job_id uuid references public.jobs(id) on delete cascade, skill_id uuid not null references public.skills(id) on delete cascade,
  priority smallint not null default 3, reason text not null, estimated_hours numeric(6,1),
  status text not null default 'recomendado', created_at timestamptz not null default now()
);
create table if not exists public.talent_preferences (
  candidate_id uuid primary key references public.candidate_profiles(profile_id) on delete cascade,
  max_commute_km numeric(6,1) default 40, preferred_shifts text[] default '{}',
  available_days text[] default '{}', min_salary numeric(12,2), updated_at timestamptz not null default now()
);
create index if not exists idx_applications_candidate on public.applications(candidate_id);
create index if not exists idx_candidate_skills_skill on public.candidate_skills(skill_id);
create index if not exists idx_companies_created_by on public.companies(created_by);
create index if not exists idx_company_members_user on public.company_members(user_id);
create index if not exists idx_job_skills_skill on public.job_skills(skill_id);
create index if not exists idx_jobs_company on public.jobs(company_id);
create index if not exists idx_matches_candidate on public.matches(candidate_id);
create index if not exists idx_skill_evidence_skill on public.skill_evidence(skill_id);
create index if not exists idx_training_job on public.training_recommendations(job_id);
create index if not exists idx_training_skill on public.training_recommendations(skill_id);
create index if not exists idx_skills_parent on public.skills(parent_skill_id);
alter table public.skill_evidence enable row level security;
alter table public.skill_assessments enable row level security;
alter table public.training_recommendations enable row level security;
alter table public.talent_preferences enable row level security;
drop policy if exists "evidence_access" on public.skill_evidence;
create policy "evidence_access" on public.skill_evidence for select to authenticated
using(candidate_id=(select auth.uid()) or exists(select 1 from public.candidate_profiles cp where cp.profile_id=candidate_id and cp.searchable));
drop policy if exists "evidence_insert" on public.skill_evidence;
create policy "evidence_insert" on public.skill_evidence for insert to authenticated with check(candidate_id=(select auth.uid()));
drop policy if exists "evidence_update" on public.skill_evidence;
create policy "evidence_update" on public.skill_evidence for update to authenticated using(candidate_id=(select auth.uid())) with check(candidate_id=(select auth.uid()));
drop policy if exists "evidence_delete" on public.skill_evidence;
create policy "evidence_delete" on public.skill_evidence for delete to authenticated using(candidate_id=(select auth.uid()));
drop policy if exists "assessment_visibility" on public.skill_assessments;
create policy "assessment_visibility" on public.skill_assessments for select to authenticated
using(candidate_id=(select auth.uid()) or exists(select 1 from public.jobs j join public.company_members cm on cm.company_id=j.company_id where j.id=job_id and cm.user_id=(select auth.uid())));
create policy "candidate_assessment_insert" on public.skill_assessments for insert to authenticated with check(candidate_id=(select auth.uid()));
drop policy if exists "training_visibility" on public.training_recommendations;
create policy "training_visibility" on public.training_recommendations for select to authenticated
using(candidate_id=(select auth.uid()) or exists(select 1 from public.jobs j join public.company_members cm on cm.company_id=j.company_id where j.id=job_id and cm.user_id=(select auth.uid())));
create policy "candidate_training_update" on public.training_recommendations for update to authenticated using(candidate_id=(select auth.uid())) with check(candidate_id=(select auth.uid()));
drop policy if exists "preference_self" on public.talent_preferences;
create policy "preference_self" on public.talent_preferences for all to authenticated using(candidate_id=(select auth.uid())) with check(candidate_id=(select auth.uid()));
drop view if exists public.skill_market_summary;
create view public.skill_market_summary with (security_invoker=true) as
select s.id,s.name,s.category,coalesce(cs.talent_count,0) talent_count,coalesce(js.job_count,0) job_count,
case when coalesce(js.job_count,0)=0 then 0 else round(coalesce(js.job_count,0)::numeric/greatest(cs.talent_count,1),2) end demand_pressure
from public.skills s
left join (select cs2.skill_id,count(distinct cs2.candidate_id)::int talent_count from public.candidate_skills cs2 join public.candidate_profiles cp on cp.profile_id=cs2.candidate_id and cp.searchable group by cs2.skill_id) cs on cs.skill_id=s.id
left join (select js2.skill_id,count(distinct js2.job_id)::int job_count from public.job_skills js2 join public.jobs j on j.id=js2.job_id and j.status='aberta' group by js2.skill_id) js on js.skill_id=s.id;
grant select on public.skill_market_summary to authenticated;
drop function if exists public.calculate_readiness(uuid,uuid);
create function public.calculate_readiness(p_candidate_id uuid,p_job_id uuid) returns jsonb
language sql stable security invoker set search_path=public as $$
with req as(select js.skill_id,js.required,coalesce(js.min_proficiency,3) min_proficiency from public.job_skills js where js.job_id=p_job_id),
have as(select cs.skill_id,cs.verified,cs.proficiency from public.candidate_skills cs where cs.candidate_id=p_candidate_id),
agg as(select count(*) filter(where r.required)::numeric req_count,count(*) filter(where r.required and h.skill_id is not null)::numeric covered_count,
count(*) filter(where r.required and h.skill_id is not null and h.verified)::numeric verified_count,
count(*) filter(where r.required and h.proficiency>=r.min_proficiency)::numeric level_count
from req r left join have h on h.skill_id=r.skill_id)
select jsonb_build_object('readiness',least(100,round(case when req_count=0 then 0 else covered_count/req_count*55+verified_count/req_count*20+level_count/req_count*15+10 end,0)),
'coverage',case when req_count=0 then 0 else round(covered_count/req_count*100,0) end,
'verification',case when req_count=0 then 0 else round(verified_count/req_count*100,0) end,
'missing_count',greatest(req_count-covered_count,0)) from agg;
$$;
revoke all on function public.calculate_readiness(uuid,uuid) from public;
grant execute on function public.calculate_readiness(uuid,uuid) to authenticated;
