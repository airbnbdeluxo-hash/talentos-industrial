-- Regression for migration 20261012221728_block_closed_job_applications.sql.
-- IMPORTANT: run only AFTER the migration has been applied in the target environment.
-- Fixture data is synthetic and disappears with ROLLBACK; no emails or file bytes.
begin;
select set_config('request.jwt.claim.sub','d4200000-0000-4000-8000-000000000001',true);
insert into auth.users(id,email,raw_app_meta_data) values
  ('d4200000-0000-4000-8000-000000000001','qa-closed-candidate@example.invalid','{"role":"candidato"}'),
  ('d4200000-0000-4000-8000-000000000002','qa-closed-owner@example.invalid','{"role":"empresa"}');
insert into public.candidate_profiles(profile_id,display_name,city,searchable,visibility_consent_at,consent_version)
values ('d4200000-0000-4000-8000-000000000001','QA Applicant','Caxias do Sul — RS',true,now(),'v1');
insert into public.companies(id,name,city,created_by) values
('d4200000-0000-4000-8000-000000000020','QA Employer','Caxias do Sul — RS','d4200000-0000-4000-8000-000000000002');
insert into public.company_members(company_id,user_id,member_role) values
('d4200000-0000-4000-8000-000000000020','d4200000-0000-4000-8000-000000000002','owner');
insert into public.jobs(id,company_id,title,city,status) values
('d4200000-0000-4000-8000-000000000030','d4200000-0000-4000-8000-000000000020','QA OPEN','Caxias do Sul — RS','aberta'),
('d4200000-0000-4000-8000-000000000031','d4200000-0000-4000-8000-000000000020','QA CLOSED','Caxias do Sul — RS','fechada'),
('d4200000-0000-4000-8000-000000000032','d4200000-0000-4000-8000-000000000020','QA OPEN FAKE HIRE','Caxias do Sul — RS','aberta'),
('d4200000-0000-4000-8000-000000000033','d4200000-0000-4000-8000-000000000020','QA OPEN FAKE REJECT','Caxias do Sul — RS','aberta');
set local role authenticated;
insert into public.applications(id,job_id,candidate_id,status) values
('d4200000-0000-4000-8000-000000000040','d4200000-0000-4000-8000-000000000030',auth.uid(),'novo');
do $$ declare closed_was_blocked boolean := false; hired_was_blocked boolean := false; fake_rejection_was_blocked boolean := false; begin
  begin
    insert into public.applications(id,job_id,candidate_id,status) values
    ('d4200000-0000-4000-8000-000000000041','d4200000-0000-4000-8000-000000000031',auth.uid(),'novo');
  exception when insufficient_privilege then
    closed_was_blocked := true;
  end;
  if not closed_was_blocked then
    raise exception 'FAIL: authenticated candidate can apply to closed job';
  end if;
  begin
    insert into public.applications(id,job_id,candidate_id,status) values
    ('d4200000-0000-4000-8000-000000000042','d4200000-0000-4000-8000-000000000032',auth.uid(),'contratado');
  exception when insufficient_privilege then
    hired_was_blocked := true;
  end;
  if not hired_was_blocked then
    raise exception 'FAIL: candidate inserted an already hired application';
  end if;
  begin
    insert into public.applications(id,job_id,candidate_id,status,rejection_reason_code) values
    ('d4200000-0000-4000-8000-000000000043','d4200000-0000-4000-8000-000000000033',auth.uid(),'novo','outro');
  exception when insufficient_privilege then
    fake_rejection_was_blocked := true;
  end;
  if not fake_rejection_was_blocked then
    raise exception 'FAIL: candidate inserted employer rejection metadata';
  end if;
  if (select count(*) from public.applications where candidate_id=auth.uid()) <> 1 then
    raise exception 'FAIL: expected exactly one open application';
  end if;
end $$;
reset role;
rollback;
select 'PASS: open job accepted; closed job, forged hired status and forged rejection denied; all fixtures rolled back' as result;
