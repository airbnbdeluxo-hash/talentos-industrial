drop policy if exists jobskills_delete on public.job_skills;
create policy jobskills_delete
on public.job_skills
for delete
to authenticated
using (
  private.is_admin()
  or exists (
    select 1
    from public.jobs j
    join public.company_members cm on cm.company_id=j.company_id
    where j.id=job_skills.job_id
      and cm.user_id=(select auth.uid())
      and cm.member_role in ('owner','recruiter')
  )
);

create or replace function public.update_job_details(
  p_job_id uuid,
  p_title text,
  p_description text,
  p_city text,
  p_salary_min numeric,
  p_salary_max numeric,
  p_shift text,
  p_skills text[],
  p_screening_questions text[] default '{}',
  p_employment_type text default 'CLT',
  p_work_model text default 'Presencial',
  p_benefits text[] default '{}',
  p_travel_required boolean default false,
  p_interview_questions text[] default '{}'
)
returns public.jobs
language plpgsql
security invoker
set search_path = ''
as $function$
declare result_row public.jobs; skill_count integer;
begin
  if (select auth.uid()) is null then raise exception 'authentication required'; end if;
  if nullif(btrim(p_title),'') is null then raise exception 'job title required'; end if;
  if p_salary_min is not null and p_salary_max is not null and p_salary_min > p_salary_max then raise exception 'invalid salary range'; end if;
  if coalesce(array_length(p_skills,1),0)=0 then raise exception 'at least one skill required'; end if;
  select count(distinct s.name) into skill_count from public.skills s where s.name = any(p_skills);
  if skill_count <> (select count(distinct x) from unnest(p_skills) x) then raise exception 'one or more skills were not found'; end if;
  update public.jobs j set
    title=btrim(p_title),description=nullif(btrim(coalesce(p_description,'')),''),
    city=p_city,salary_min=p_salary_min,salary_max=p_salary_max,
    shift=nullif(btrim(coalesce(p_shift,'')),''),
    screening_questions=coalesce(p_screening_questions,'{}'::text[]),
    employment_type=coalesce(nullif(btrim(p_employment_type),''),'CLT'),
    work_model=coalesce(nullif(btrim(p_work_model),''),'Presencial'),
    benefits=coalesce(p_benefits,'{}'::text[]),
    travel_required=coalesce(p_travel_required,false),
    interview_questions=coalesce(p_interview_questions,'{}'::text[])
  where j.id=p_job_id returning j.* into result_row;
  if result_row.id is null then raise exception 'job not found or not authorized'; end if;
  delete from public.job_skills js where js.job_id=p_job_id;
  insert into public.job_skills(job_id,skill_id,required,min_proficiency,weight)
  select p_job_id,s.id,true,3,1 from public.skills s where s.name = any(p_skills);
  perform public.log_audit_event('job_updated','job',p_job_id,jsonb_build_object('skills',p_skills,'status',result_row.status));
  return result_row;
end;
$function$;

revoke execute on function public.update_job_details(uuid,text,text,text,numeric,numeric,text,text[],text[],text,text,text[],boolean,text[]) from public, anon;
grant execute on function public.update_job_details(uuid,text,text,text,numeric,numeric,text,text[],text[],text,text,text[],boolean,text[]) to authenticated;