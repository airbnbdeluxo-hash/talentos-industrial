-- TalentOS Industrial: production grants, storage and server-side matching
-- Fix membership policy to avoid self-recursive RLS.
drop policy if exists "company members own company select" on public.company_members;
create policy "company members self select" on public.company_members for select to authenticated
using (user_id = (select auth.uid()));

-- Only company members can browse candidate data; candidates always see their own profile.
drop policy if exists "searchable candidates readable to companies" on public.candidate_profiles;
create policy "candidate visibility" on public.candidate_profiles for select to authenticated
using (
  profile_id = (select auth.uid())
  or (
    searchable
    and exists (
      select 1 from public.company_members cm
      where cm.user_id=(select auth.uid())
        and cm.member_role in ('owner','recruiter','viewer')
    )
  )
);

drop policy if exists "candidate skills readable" on public.candidate_skills;
create policy "candidate skills visibility" on public.candidate_skills for select to authenticated
using (
  candidate_id = (select auth.uid())
  or (
    exists (select 1 from public.candidate_profiles cp where cp.profile_id=candidate_id and cp.searchable)
    and exists (
      select 1 from public.company_members cm
      where cm.user_id=(select auth.uid())
        and cm.member_role in ('owner','recruiter','viewer')
    )
  )
);

-- Least-privilege table grants for browser roles.
revoke all on table public.profiles, public.companies, public.company_members, public.candidate_profiles,
  public.candidate_skills, public.jobs, public.job_skills, public.matches, public.applications from anon;
grant select on table public.skills to anon;
grant select, insert, update on table public.profiles to authenticated;
grant select, insert, update on table public.companies to authenticated;
grant select, insert on table public.company_members to authenticated;
grant select, insert, update on table public.candidate_profiles to authenticated;
grant select, insert, update, delete on table public.candidate_skills to authenticated;
grant select, insert, update on table public.jobs to authenticated;
grant select, insert, update on table public.job_skills to authenticated;
grant select, insert on table public.matches to authenticated;
grant select, insert, update on table public.applications to authenticated;

-- Private evidence storage.
insert into storage.buckets (id,name,public)
values ('candidate-evidence','candidate-evidence',false)
on conflict (id) do update set public=false;

drop policy if exists "candidate evidence insert" on storage.objects;
create policy "candidate evidence insert" on storage.objects
for insert to authenticated
with check (
  bucket_id='candidate-evidence'
  and (storage.foldername(name))[1]=(select auth.uid())::text
);

drop policy if exists "candidate evidence read" on storage.objects;
create policy "candidate evidence read" on storage.objects
for select to authenticated
using (
  bucket_id='candidate-evidence'
  and (
    (storage.foldername(name))[1]=(select auth.uid())::text
    or exists (
      select 1 from public.company_members cm
      where cm.user_id=(select auth.uid())
        and cm.member_role in ('owner','recruiter','viewer')
    )
  )
);

drop policy if exists "candidate evidence delete" on storage.objects;
create policy "candidate evidence delete" on storage.objects
for delete to authenticated
using (
  bucket_id='candidate-evidence'
  and (storage.foldername(name))[1]=(select auth.uid())::text
);

-- Server-side, deterministic match calculation.
create or replace function public.generate_matches_for_job(p_job_id uuid)
returns table(
  candidate_id uuid,
  score numeric,
  reasons jsonb,
  gaps jsonb
)
language sql
security invoker
set search_path = public
as $$
  with target as (
    select j.id,j.company_id,j.city,j.salary_min,j.salary_max,
           array_agg(js.skill_id) filter (where js.required) as required_skills
    from public.jobs j
    left join public.job_skills js on js.job_id=j.id
    where j.id=p_job_id
    group by j.id,j.company_id,j.city,j.salary_min,j.salary_max
  ),
  eligible as (
    select cp.profile_id,cp.years_experience,cp.desired_salary,
           p.city,
           array_agg(cs.skill_id) filter (where cs.skill_id is not null) as skill_ids,
           array_agg(cs.skill_id) filter (where cs.verified) as verified_ids
    from public.candidate_profiles cp
    join public.profiles p on p.id=cp.profile_id
    left join public.candidate_skills cs on cs.candidate_id=cp.profile_id
    where cp.searchable or cp.profile_id=(select auth.uid())
    group by cp.profile_id,cp.years_experience,cp.desired_salary,p.city
  ),
  calc as (
    select e.profile_id,
      coalesce((select count(*) from unnest(t.required_skills) r where r=e.skill_ids @> array[r]),0)::numeric as covered,
      coalesce((select count(*) from unnest(t.required_skills) r where r=e.verified_ids @> array[r]),0)::numeric as verified,
      cardinality(coalesce(t.required_skills,array[]::uuid[]))::numeric as req,
      case when e.city=t.city then 12 else 4 end::numeric as location_bonus,
      least(coalesce(e.years_experience,0)/5,1)*10 as exp_bonus,
      case when e.desired_salary is not null and t.salary_min is not null and t.salary_max is not null
                 and e.desired_salary between t.salary_min and t.salary_max then 8 else 0 end::numeric as salary_bonus,
      t.required_skills,e.skill_ids
    from eligible e cross join target t
  )
  select c.profile_id,
    least(100,round((case when c.req=0 then 0 else c.covered/c.req*65 end)
      +(case when c.req=0 then 0 else c.verified/c.req*10 end)
      +c.location_bonus+c.exp_bonus+c.salary_bonus,0)) as score,
    jsonb_build_array(
      case when c.req=0 then 'Sem skills obrigatórias' when c.covered=c.req then 'Todas as skills exigidas atendidas'
           else concat(c.covered::int,'/',c.req::int,' skills atendidas') end,
      concat(c.verified::int,' skills verificadas'),
      case when c.location_bonus=12 then 'Mesma cidade' else 'Região diferente' end,
      case when c.salary_bonus=8 then 'Pretensão dentro da faixa' else 'Pretensão fora da faixa' end
    ) as reasons,
    coalesce((
      select jsonb_agg(s.name order by s.name)
      from public.skills s
      where s.id = any(coalesce(c.required_skills,array[]::uuid[]))
        and not (coalesce(c.skill_ids,array[]::uuid[]) @> array[s.id])
    ),'[]'::jsonb) as gaps
  from calc c
  order by 2 desc;
$$;

grant execute on function public.generate_matches_for_job(uuid) to authenticated;
