-- Outcome Loop -> Skill Passport / training / rematching regression test.
-- All fixtures are disposable; the transaction is rolled back.

begin;

select set_config('request.jwt.claim.sub','b2000000-0000-4000-8000-000000000001',true);

insert into auth.users(id,email,raw_app_meta_data) values
 ('b2000000-0000-4000-8000-000000000001','outcome-loop-candidate@example.invalid','{"role":"candidato"}'),
 ('b2000000-0000-4000-8000-000000000002','outcome-loop-reviewer@example.invalid','{"role":"empresa"}'),
 ('b2000000-0000-4000-8000-000000000003','outcome-loop-other@example.invalid','{"role":"empresa"}');

insert into public.candidate_profiles(profile_id,display_name,role_title,city,searchable,visibility_consent_at,consent_version)
values('b2000000-0000-4000-8000-000000000001','QA Outcome','Operador QA','Caxias do Sul — RS',true,now(),'v1');

insert into public.skills(id,name,category)
values('b2000000-0000-4000-8000-000000000010','QA Outcome Skill 20260930','QA');

insert into public.companies(id,name,city,created_by)
values('b2000000-0000-4000-8000-000000000020','QA Outcome Company','Caxias do Sul — RS','b2000000-0000-4000-8000-000000000002');

insert into public.company_members(company_id,user_id,member_role)
values('b2000000-0000-4000-8000-000000000020','b2000000-0000-4000-8000-000000000002','owner');

insert into public.jobs(id,company_id,title,city,status)
values('b2000000-0000-4000-8000-000000000030','b2000000-0000-4000-8000-000000000020','QA Outcome Job','Caxias do Sul — RS','aberta');

insert into public.job_skills(job_id,skill_id,min_proficiency,required,weight)
values('b2000000-0000-4000-8000-000000000030','b2000000-0000-4000-8000-000000000010',3,true,1::numeric);

insert into public.applications(id,job_id,candidate_id,status)
values('b2000000-0000-4000-8000-000000000031','b2000000-0000-4000-8000-000000000030','b2000000-0000-4000-8000-000000000001','contratado');

insert into public.candidate_skills(candidate_id,skill_id,proficiency,verified,source_type,years_experience)
values('b2000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000010',1,false,'manual',1);

set local role authenticated;
select set_config('request.jwt.claim.sub','b2000000-0000-4000-8000-000000000002',true);

do $$
declare
  o30 public.employment_outcomes;
  s30 public.employment_outcome_skill_signals;
  o60 public.employment_outcomes;
  o90 public.employment_outcomes;
  v_count integer;
begin
  o30 := public.record_employment_outcome(
    'b2000000-0000-4000-8000-000000000031'::uuid,'30d',
    90::numeric,20::smallint,'ativo','{}'::jsonb,'QA 30d'
  );

  s30 := public.save_employment_outcome_skill_signal(
    o30.id,'b2000000-0000-4000-8000-000000000010'::uuid,
    'utilizada',5::smallint,false,'Aplicação consistente'
  );

  if (select proficiency from public.candidate_skills
      where candidate_id='b2000000-0000-4000-8000-000000000001'
        and skill_id='b2000000-0000-4000-8000-000000000010') <> 2 then
    raise exception 'FAIL 30d bounded progression';
  end if;

  if (select verified from public.candidate_skills
      where candidate_id='b2000000-0000-4000-8000-000000000001'
        and skill_id='b2000000-0000-4000-8000-000000000010') then
    raise exception 'FAIL outcome auto verified skill';
  end if;

  if (select source_type from public.candidate_skills
      where candidate_id='b2000000-0000-4000-8000-000000000001'
        and skill_id='b2000000-0000-4000-8000-000000000010') <> 'outcome' then
    raise exception 'FAIL outcome provenance';
  end if;

  select count(*) into v_count
  from public.candidate_skill_outcome_events
  where outcome_signal_id=s30.id;
  if v_count <> 1 then raise exception 'FAIL outcome event'; end if;

  perform public.save_employment_outcome_skill_signal(
    o30.id,'b2000000-0000-4000-8000-000000000010'::uuid,
    'utilizada',5::smallint,false,'Repetição idempotente'
  );

  if (select count(*) from public.candidate_skill_outcome_events where outcome_signal_id=s30.id) <> 1 then
    raise exception 'FAIL idempotency event';
  end if;

  if (select proficiency from public.candidate_skills
      where candidate_id='b2000000-0000-4000-8000-000000000001'
        and skill_id='b2000000-0000-4000-8000-000000000010') <> 2 then
    raise exception 'FAIL idempotency proficiency';
  end if;

  o60 := public.record_employment_outcome(
    'b2000000-0000-4000-8000-000000000031'::uuid,'60d',
    88::numeric,25::smallint,'ativo','{}'::jsonb,'QA 60d'
  );

  perform public.save_employment_outcome_skill_signal(
    o60.id,'b2000000-0000-4000-8000-000000000010'::uuid,
    'utilizada',4::smallint,false,'Autonomia observada'
  );

  if (select proficiency from public.candidate_skills
      where candidate_id='b2000000-0000-4000-8000-000000000001'
        and skill_id='b2000000-0000-4000-8000-000000000010') <> 3 then
    raise exception 'FAIL 60d progression';
  end if;

  if not exists(
    select 1 from public.matches
    where job_id='b2000000-0000-4000-8000-000000000030'
      and candidate_id='b2000000-0000-4000-8000-000000000001'
  ) then
    raise exception 'FAIL targeted rematching';
  end if;

  o90 := public.record_employment_outcome(
    'b2000000-0000-4000-8000-000000000031'::uuid,'90d',
    90::numeric,25::smallint,'ativo','{}'::jsonb,'QA 90d'
  );

  perform public.save_employment_outcome_skill_signal(
    o90.id,'b2000000-0000-4000-8000-000000000010'::uuid,
    'necessita_desenvolvimento',2::smallint,true,'Precisa aprofundar setup'
  );

  if (select proficiency from public.candidate_skills
      where candidate_id='b2000000-0000-4000-8000-000000000001'
        and skill_id='b2000000-0000-4000-8000-000000000010') <> 3 then
    raise exception 'FAIL development signal downgraded skill';
  end if;

  if not exists(
    select 1 from public.training_recommendations
    where candidate_id='b2000000-0000-4000-8000-000000000001'
      and job_id='b2000000-0000-4000-8000-000000000030'
      and skill_id='b2000000-0000-4000-8000-000000000010'
      and status='recomendado'
      and priority=5
  ) then
    raise exception 'FAIL outcome training recommendation';
  end if;
end $$;

select set_config('request.jwt.claim.sub','b2000000-0000-4000-8000-000000000003',true);

do $$
declare v_signal uuid;
begin
  select id into v_signal from public.employment_outcome_skill_signals limit 1;
  begin
    perform private.apply_employment_outcome_skill_signal(v_signal);
    raise exception 'FAIL unauthorized outcome application';
  exception when raise_exception then
    if sqlerrm like 'FAIL%' then raise; end if;
  end;
end $$;

do $$
begin
  if has_function_privilege('anon','public.record_employment_outcome(uuid,text,numeric,smallint,text,jsonb,text)','execute') then
    raise exception 'FAIL anon outcome RPC privilege';
  end if;
  if has_function_privilege('anon','public.save_employment_outcome_skill_signal(uuid,uuid,text,smallint,boolean,text)','execute') then
    raise exception 'FAIL anon signal RPC privilege';
  end if;
  if has_table_privilege('authenticated','public.candidate_skill_outcome_events','insert') then
    raise exception 'FAIL outcome event forgery privilege';
  end if;
end $$;

rollback;

select 'PASS: outcome progression, no auto-verification, provenance, idempotency, rematching, training feedback, authorization and grants' as result;
