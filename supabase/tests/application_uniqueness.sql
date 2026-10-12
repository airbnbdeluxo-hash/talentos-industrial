-- Synthetic duplicate application regression. Rollback removes every fixture.
-- The unique (job_id,candidate_id) index is the definitive race-condition guard.
begin;
do $$ begin
  if not exists (
    select 1 from pg_index i
    join pg_class t on t.oid=i.indrelid
    join pg_namespace n on n.oid=t.relnamespace
    where n.nspname='public' and t.relname='applications' and i.indisunique
      and (select array_agg(a.attname order by k.ordinality)
           from unnest(i.indkey) with ordinality as k(attnum,ordinality)
           join pg_attribute a on a.attrelid=t.oid and a.attnum=k.attnum)
          = array['job_id','candidate_id']::name[]
  ) then raise exception 'FAIL missing database-enforced unique application pair'; end if;
end $$;
select set_config('request.jwt.claim.sub','c3600000-0000-4000-8000-000000000001',true);
insert into auth.users(id,email,raw_app_meta_data) values
 ('c3600000-0000-4000-8000-000000000001','qa-unique-candidate@example.invalid','{"role":"candidato"}'),
 ('c3600000-0000-4000-8000-000000000002','qa-unique-owner@example.invalid','{"role":"empresa"}');
insert into public.candidate_profiles(profile_id,display_name,city,searchable,visibility_consent_at,consent_version)
 values('c3600000-0000-4000-8000-000000000001','QA Application Unique','Caxias do Sul — RS',true,now(),'v1');
insert into public.companies(id,name,city,created_by)
 values('c3600000-0000-4000-8000-000000000020','QA Application Unique Company','Caxias do Sul — RS','c3600000-0000-4000-8000-000000000002');
insert into public.company_members(company_id,user_id,member_role)
 values('c3600000-0000-4000-8000-000000000020','c3600000-0000-4000-8000-000000000002','owner');
insert into public.jobs(id,company_id,title,city,status)
 values('c3600000-0000-4000-8000-000000000030','c3600000-0000-4000-8000-000000000020','QA Application Unique Job','Caxias do Sul — RS','aberta');
set local role authenticated;
insert into public.applications(id,job_id,candidate_id,status)
 values('c3600000-0000-4000-8000-000000000031','c3600000-0000-4000-8000-000000000030',auth.uid(),'novo');
do $$ declare duplicate_blocked boolean := false; begin
  begin
    insert into public.applications(id,job_id,candidate_id,status)
     values('c3600000-0000-4000-8000-000000000032','c3600000-0000-4000-8000-000000000030',auth.uid(),'novo');
  exception when unique_violation then duplicate_blocked := true;
  end;
  if not duplicate_blocked then raise exception 'FAIL duplicate application accepted'; end if;
  if (select count(*) from public.applications
      where job_id='c3600000-0000-4000-8000-000000000030' and candidate_id=auth.uid()) <> 1 then
    raise exception 'FAIL duplicate attempt altered application count';
  end if;
end $$;
rollback;
select 'PASS: database unique constraint rejects duplicate application; one candidate-job pair remains before rollback' as result;
