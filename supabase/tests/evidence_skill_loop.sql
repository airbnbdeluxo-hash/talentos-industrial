-- Disposable fixtures; all changes rolled back, including auth users and notifications.
begin;
select set_config('request.jwt.claim.sub','a1000000-0000-4000-8000-000000000001',true);
insert into auth.users(id,email,raw_app_meta_data) values
 ('a1000000-0000-4000-8000-000000000001','evidence-loop-candidate@example.invalid','{"role":"candidato"}'),
 ('a1000000-0000-4000-8000-000000000002','evidence-loop-reviewer@example.invalid','{"role":"empresa"}'),
 ('a1000000-0000-4000-8000-000000000003','evidence-loop-other@example.invalid','{"role":"candidato"}');
insert into public.candidate_profiles(profile_id,display_name,city,searchable,visibility_consent_at,consent_version)
 values('a1000000-0000-4000-8000-000000000001','QA Evidence','Caxias do Sul — RS',true,now(),'v1');
insert into public.skills(id,name,category) values('a1000000-0000-4000-8000-000000000010','QA Evidence Skill','QA');
insert into public.companies(id,name,city,created_by) values('a1000000-0000-4000-8000-000000000020','QA Evidence Company','Caxias do Sul — RS','a1000000-0000-4000-8000-000000000002');
insert into public.company_members(company_id,user_id,member_role) values('a1000000-0000-4000-8000-000000000020','a1000000-0000-4000-8000-000000000002','owner');
insert into public.jobs(id,company_id,title,city) values('a1000000-0000-4000-8000-000000000030','a1000000-0000-4000-8000-000000000020','QA Evidence Job','Caxias do Sul — RS');
insert into public.job_skills(job_id,skill_id,min_proficiency) values('a1000000-0000-4000-8000-000000000030','a1000000-0000-4000-8000-000000000010',3);
insert into public.applications(job_id,candidate_id) values('a1000000-0000-4000-8000-000000000030','a1000000-0000-4000-8000-000000000001');
set local role authenticated;
insert into public.candidate_skills(candidate_id,skill_id,proficiency,verified) values('a1000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000010',1,true);
insert into public.skill_evidence(id,candidate_id,skill_id,evidence_type,title,score,verified) values
 ('a1000000-0000-4000-8000-000000000040','a1000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000010','desafio','QA reviewed practical',100,true);
do $$ declare result jsonb; begin
 if (select verified from public.candidate_skills where skill_id='a1000000-0000-4000-8000-000000000010') then raise exception 'FAIL self verification'; end if;
 result:=public.apply_skill_evidence('a1000000-0000-4000-8000-000000000040');
 if result->>'status'<>'aguardando_validacao' then raise exception 'FAIL pending evidence applied'; end if;
 begin
  perform public.review_skill_evidence('a1000000-0000-4000-8000-000000000040','aprovada','Self review');
  raise exception 'FAIL self review accepted';
 exception when raise_exception then if sqlerrm like 'FAIL%' then raise; end if; end;
 begin
  update public.candidate_skills set source_type='avaliacao' where skill_id='a1000000-0000-4000-8000-000000000010';
  raise exception 'FAIL trusted source forgery';
 exception when raise_exception then if sqlerrm like 'FAIL%' then raise; end if; end;
end $$;
do $$ declare rec public.training_recommendations; v_result uuid; before_name text; begin
 select * into rec from public.generate_training_plan_for_job('a1000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000030') limit 1;
 if rec.id is null then raise exception 'FAIL no training generated'; end if;
 perform public.record_training_evidence(rec.id,'a1000000-0000-4000-8000-000000000040');
 if not exists(select 1 from public.training_evidence_links where recommendation_id=rec.id) then raise exception 'FAIL training link missing'; end if;
 if (select proficiency from public.candidate_skills where skill_id='a1000000-0000-4000-8000-000000000010')<>1 then raise exception 'FAIL pending training promoted skill'; end if;
 begin
   perform public.record_training_evidence(rec.id,'a1000000-0000-4000-8000-000000000040',null,null,'manual');
   raise exception 'FAIL wrong completion type';
 exception when raise_exception then if sqlerrm like 'FAIL%' then raise; end if; end;
 select display_name into before_name from public.candidate_profiles where profile_id=auth.uid();
 begin
   perform public.save_candidate_passport('{"name":"SHOULD ROLLBACK","city":"Caxias do Sul — RS","role":"QA"}',
     '[{"skill_id":"a1000000-0000-4000-8000-000000000099","source_type":"manual"}]');
   raise exception 'FAIL invalid skill save succeeded';
 exception when foreign_key_violation then null; end;
 if (select display_name from public.candidate_profiles where profile_id=auth.uid())<>before_name then raise exception 'FAIL profile partial save'; end if;
 if not exists(select 1 from public.candidate_skills where skill_id='a1000000-0000-4000-8000-000000000010') then raise exception 'FAIL prior skill lost'; end if;
end $$;
select set_config('request.jwt.claim.sub','a1000000-0000-4000-8000-000000000003',true);
do $$ begin
 if exists(select 1 from public.candidate_skills where candidate_id='a1000000-0000-4000-8000-000000000001') then raise exception 'FAIL another candidate can read passport'; end if;
 begin
  perform public.apply_skill_evidence('a1000000-0000-4000-8000-000000000040');
  raise exception 'FAIL third party evidence access';
 exception when raise_exception then if sqlerrm like 'FAIL%' then raise; end if; end;
end $$;
select set_config('request.jwt.claim.sub','a1000000-0000-4000-8000-000000000002',true);
select public.review_skill_evidence('a1000000-0000-4000-8000-000000000040','aprovada','QA review');
select public.generate_matches_for_job('a1000000-0000-4000-8000-000000000030');
select set_config('request.jwt.claim.sub','a1000000-0000-4000-8000-000000000001',true);
do $$ declare result jsonb; begin
 if (select proficiency from public.candidate_skills where skill_id='a1000000-0000-4000-8000-000000000010')<>2 then raise exception 'FAIL bounded progression'; end if;
 if (select count(*) from public.candidate_skill_events where evidence_id='a1000000-0000-4000-8000-000000000040')<>1 then raise exception 'FAIL missing audit event'; end if;
 if not exists(select 1 from public.matches where job_id='a1000000-0000-4000-8000-000000000030' and score>50) then raise exception 'FAIL matching refresh'; end if;
 result:=public.apply_skill_evidence('a1000000-0000-4000-8000-000000000040');
 if result->>'status'<>'ja_aplicada' then raise exception 'FAIL idempotency'; end if;
 update public.candidate_skills set proficiency=5,source_confidence=1 where skill_id='a1000000-0000-4000-8000-000000000010';
 if (select proficiency from public.candidate_skills where skill_id='a1000000-0000-4000-8000-000000000010')<>2 then raise exception 'FAIL trusted proficiency overwritten'; end if;
 if has_function_privilege('anon','public.apply_skill_evidence(uuid)','execute') then raise exception 'FAIL anon RPC privilege'; end if;
 if has_table_privilege('authenticated','public.candidate_skill_events','insert') then raise exception 'FAIL audit event forgery privilege'; end if;
end $$;
do $$ begin
 perform public.save_candidate_passport('{"name":"QA Updated","city":"Caxias do Sul — RS","role":"QA","searchable":true}', '[]');
 if not exists(select 1 from public.candidate_skills where skill_id='a1000000-0000-4000-8000-000000000010' and verified and proficiency=2) then raise exception 'FAIL reviewed skill lost on resume save'; end if;
end $$;
rollback;
select 'PASS: pending, ownership, self-review, provenance, bounded progression, audit, rematching, idempotency, grants, training linkage and atomic rollback' as result;
