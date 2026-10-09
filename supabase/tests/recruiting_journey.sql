-- Synthetic fixtures only. Run as a database administrator; all writes roll back.
begin;
select set_config('request.jwt.claim.sub','c3000000-0000-4000-8000-000000000001',true);
insert into auth.users(id,email,raw_app_meta_data) values
 ('c3000000-0000-4000-8000-000000000001','qa-candidate@example.invalid','{"role":"candidato"}'),
 ('c3000000-0000-4000-8000-000000000002','qa-owner@example.invalid','{"role":"empresa"}'),
 ('c3000000-0000-4000-8000-000000000003','qa-other-owner@example.invalid','{"role":"empresa"}'),
 ('c3000000-0000-4000-8000-000000000004','qa-viewer@example.invalid','{"role":"empresa"}'),
 ('c3000000-0000-4000-8000-000000000005','qa-other-candidate@example.invalid','{"role":"candidato"}');
insert into public.candidate_profiles(profile_id,display_name,city,searchable,visibility_consent_at,consent_version)
 values('c3000000-0000-4000-8000-000000000001','QA recruiting candidate','Caxias do Sul — RS',true,now(),'v1');
insert into public.companies(id,name,city,created_by) values
 ('c3000000-0000-4000-8000-000000000020','QA recruiting company','Caxias do Sul — RS','c3000000-0000-4000-8000-000000000002'),
 ('c3000000-0000-4000-8000-000000000021','QA other company','Caxias do Sul — RS','c3000000-0000-4000-8000-000000000003');
insert into public.company_members(company_id,user_id,member_role) values
 ('c3000000-0000-4000-8000-000000000020','c3000000-0000-4000-8000-000000000002','owner'),
 ('c3000000-0000-4000-8000-000000000020','c3000000-0000-4000-8000-000000000004','viewer'),
 ('c3000000-0000-4000-8000-000000000021','c3000000-0000-4000-8000-000000000003','owner');

set local role authenticated;
select set_config('request.jwt.claim.sub','c3000000-0000-4000-8000-000000000002',true);
insert into public.jobs(id,company_id,title,city,status,salary_min) values
 ('c3000000-0000-4000-8000-000000000030','c3000000-0000-4000-8000-000000000020','QA Operador CNC','Caxias do Sul — RS','aberta',3500);
select set_config('request.jwt.claim.sub','c3000000-0000-4000-8000-000000000001',true);
insert into public.applications(id,job_id,candidate_id,status) values
 ('c3000000-0000-4000-8000-000000000031','c3000000-0000-4000-8000-000000000030',auth.uid(),'novo');
insert into public.saved_jobs(candidate_id,job_id) values(auth.uid(),'c3000000-0000-4000-8000-000000000030');
insert into public.job_alerts(candidate_id,name,cargo,city) values(auth.uid(),'QA alert','Operador CNC','Caxias do Sul — RS');
insert into public.candidate_availability(candidate_id,weekday,start_time,end_time) values(auth.uid(),1,'09:00','12:00');
do $$ begin
 begin
  insert into public.messages(application_id,sender_id,recipient_id,body) values
   ('c3000000-0000-4000-8000-000000000031',auth.uid(),'c3000000-0000-4000-8000-000000000003','Wrong company');
  raise exception 'FAIL cross-company recipient accepted';
 exception when insufficient_privilege then null; end;
 begin
  insert into public.messages(application_id,sender_id,recipient_id,body) values
   ('c3000000-0000-4000-8000-000000000031','c3000000-0000-4000-8000-000000000002',auth.uid(),'Forged sender');
  raise exception 'FAIL forged sender accepted';
 exception when insufficient_privilege then null; end;
end $$;
insert into public.messages(application_id,sender_id,recipient_id,body) values
 ('c3000000-0000-4000-8000-000000000031',auth.uid(),'c3000000-0000-4000-8000-000000000002','Mensagem fictícia de teste');
do $$ begin
 begin
  perform public.update_application_status('c3000000-0000-4000-8000-000000000031','contratado');
  raise exception 'FAIL candidate hired self';
 exception when raise_exception then if sqlerrm like 'FAIL%' then raise; end if; end;
end $$;

select set_config('request.jwt.claim.sub','c3000000-0000-4000-8000-000000000002',true);
select public.update_application_status('c3000000-0000-4000-8000-000000000031','triagem');
select public.update_application_status('c3000000-0000-4000-8000-000000000031','entrevista');
insert into public.interviews(id,application_id,scheduled_at,interviewer_id) values
 ('c3000000-0000-4000-8000-000000000040','c3000000-0000-4000-8000-000000000031',now()+interval '2 days',auth.uid());
insert into public.application_notes(application_id,author_id,body) values
 ('c3000000-0000-4000-8000-000000000031',auth.uid(),'QA internal note');
insert into public.offers(id,application_id,salary,status,created_by) values
 ('c3000000-0000-4000-8000-000000000050','c3000000-0000-4000-8000-000000000031',3500,'enviada',auth.uid());

select set_config('request.jwt.claim.sub','c3000000-0000-4000-8000-000000000004',true);
do $$ begin
 if not exists(select 1 from public.applications where id='c3000000-0000-4000-8000-000000000031') then raise exception 'FAIL viewer cannot view application'; end if;
 begin
  perform public.update_application_status('c3000000-0000-4000-8000-000000000031','contratado');
  raise exception 'FAIL viewer changed application';
 exception when raise_exception then if sqlerrm like 'FAIL%' then raise; end if; end;
end $$;

select set_config('request.jwt.claim.sub','c3000000-0000-4000-8000-000000000003',true);
do $$ begin
 if exists(select 1 from public.applications where id='c3000000-0000-4000-8000-000000000031') then raise exception 'FAIL cross-company application read'; end if;
 if exists(select 1 from public.messages where application_id='c3000000-0000-4000-8000-000000000031') then raise exception 'FAIL cross-company messages read'; end if;
 if exists(select 1 from public.offers where id='c3000000-0000-4000-8000-000000000050') then raise exception 'FAIL cross-company offer read'; end if;
 begin
  perform public.update_application_status('c3000000-0000-4000-8000-000000000031','contratado');
  raise exception 'FAIL cross-company mutation';
 exception when raise_exception then if sqlerrm like 'FAIL%' then raise; end if; end;
end $$;

select set_config('request.jwt.claim.sub','c3000000-0000-4000-8000-000000000005',true);
do $$ begin
 if exists(select 1 from public.candidate_profiles where profile_id='c3000000-0000-4000-8000-000000000001') then raise exception 'FAIL cross-candidate profile read'; end if;
 begin
  perform public.respond_to_offer('c3000000-0000-4000-8000-000000000050','aceita');
  raise exception 'FAIL another candidate accepted offer';
 exception when raise_exception then if sqlerrm like 'FAIL%' then raise; end if; end;
end $$;

select set_config('request.jwt.claim.sub','c3000000-0000-4000-8000-000000000001',true);
select public.respond_to_interview('c3000000-0000-4000-8000-000000000040','confirmada');
select public.respond_to_offer('c3000000-0000-4000-8000-000000000050','aceita');
do $$ begin
 if (select status from public.applications where id='c3000000-0000-4000-8000-000000000031')<>'contratado' then raise exception 'FAIL accepted offer did not hire'; end if;
 if (select status from public.interviews where id='c3000000-0000-4000-8000-000000000040')<>'confirmada' then raise exception 'FAIL interview not confirmed'; end if;
 if exists(select 1 from public.application_notes where application_id='c3000000-0000-4000-8000-000000000031') then raise exception 'FAIL candidate read internal notes'; end if;
 if (select count(*) from public.application_events where application_id='c3000000-0000-4000-8000-000000000031')<4 then raise exception 'FAIL missing application history'; end if;
 if not exists(select 1 from public.notifications where user_id=auth.uid()) then raise exception 'FAIL notification missing'; end if;
end $$;

-- Server-only team transitions with explicit actor authorization.
reset role;
select public.company_team_update_member_role_service('c3000000-0000-4000-8000-000000000002','c3000000-0000-4000-8000-000000000020','c3000000-0000-4000-8000-000000000004','recruiter');
select public.company_team_transfer_owner_service('c3000000-0000-4000-8000-000000000002','c3000000-0000-4000-8000-000000000020','c3000000-0000-4000-8000-000000000004');
do $$ begin
 if (select count(*) from public.company_members where company_id='c3000000-0000-4000-8000-000000000020' and member_role='owner')<>1 then raise exception 'FAIL ownership transfer'; end if;
 begin
  perform public.company_team_remove_member_service('c3000000-0000-4000-8000-000000000003','c3000000-0000-4000-8000-000000000020','c3000000-0000-4000-8000-000000000002');
  raise exception 'FAIL unauthorized team management';
 exception when raise_exception then if sqlerrm like 'FAIL%' then raise; end if; end;
end $$;
select public.company_team_remove_member_service('c3000000-0000-4000-8000-000000000004','c3000000-0000-4000-8000-000000000020','c3000000-0000-4000-8000-000000000002');
do $$ begin
 if exists(select 1 from public.company_members where company_id='c3000000-0000-4000-8000-000000000020' and user_id='c3000000-0000-4000-8000-000000000002') then raise exception 'FAIL member removal'; end if;
end $$;
rollback;
select 'PASS: job, application, saved job, alert, availability, message, interview, offer, hiring, history, notifications, tenant isolation, candidate privacy, viewer permissions and team ownership' as result;
