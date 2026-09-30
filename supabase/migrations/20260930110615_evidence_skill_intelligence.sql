-- Reviewed evidence is a bounded, idempotent skill signal. Course completion is not validation.
-- Internal definer functions write system-owned provenance/events and scoped matches;
-- callers never receive direct write access to those system-owned fields.
create table public.candidate_skill_events (
 id uuid primary key default gen_random_uuid(),
 candidate_id uuid not null references public.candidate_profiles(profile_id) on delete cascade,
 skill_id uuid not null references public.skills(id) on delete cascade,
 evidence_id uuid not null unique references public.skill_evidence(id) on delete restrict,
 previous_proficiency smallint not null check(previous_proficiency between 0 and 5),
 new_proficiency smallint not null check(new_proficiency between 1 and 5),
 confidence numeric not null check(confidence between 0 and 1),
 source_type text not null check(source_type in ('evidencia','desafio','avaliacao')),
 policy_version text not null default 'reviewed-evidence-v1',
 explanation text not null,
 actor_id uuid not null references public.profiles(id),
 created_at timestamptz not null default now()
);
alter table public.candidate_skill_events enable row level security;
revoke all on public.candidate_skill_events from public,anon,authenticated;
grant select on public.candidate_skill_events to authenticated;
create policy candidate_skill_events_read on public.candidate_skill_events for select to authenticated
 using(candidate_id=(select auth.uid()) or (select private.is_admin()));
create index candidate_skill_events_candidate_skill_idx on public.candidate_skill_events(candidate_id,skill_id);
create index if not exists job_skills_skill_job_idx on public.job_skills(skill_id,job_id);

-- No candidate may manufacture a trusted source, or reuse a review transaction flag.
create or replace function public.protect_candidate_skill_verification()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if current_user in ('postgres','supabase_admin') or coalesce(private.is_admin(),false) then return new; end if;
 if tg_op='INSERT' then
   new.verified:=false;
   if new.source_type not in ('manual','curriculo') then raise exception 'Origem reservada à validação de evidências'; end if;
 else
   if new.candidate_id is distinct from old.candidate_id or new.skill_id is distinct from old.skill_id then
     raise exception 'A identidade da habilidade não pode ser alterada';
   end if;
   new.verified:=old.verified;
   if old.verified or old.source_type in ('evidencia','desafio','avaliacao','outcome') then
     new.proficiency:=old.proficiency;
     new.source_type:=old.source_type;
     new.source_confidence:=old.source_confidence;
     new.source_excerpt:=old.source_excerpt;
     new.source_resume_id:=old.source_resume_id;
   elsif new.source_type not in ('manual','curriculo') then
     raise exception 'Origem reservada à validação de evidências';
   end if;
 end if;
 if new.source_resume_id is not null and not exists (
   select 1 from public.candidate_resumes r where r.id=new.source_resume_id and r.candidate_id=new.candidate_id
 ) then raise exception 'Currículo não pertence ao candidato'; end if;
 return new;
end $$;

create or replace function private.refresh_candidate_job(p_candidate_id uuid,p_job_id uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'authentication required'; end if;
 delete from public.matches where job_id=p_job_id and candidate_id=p_candidate_id;
 insert into public.matches(job_id,candidate_id,score,reasons,gaps)
  with req as (
    select js.skill_id,s.name,js.min_proficiency,greatest(coalesce(js.weight,1),0.001) weight
    from public.job_skills js join public.skills s on s.id=js.skill_id
    where js.job_id=p_job_id and js.required
  ), req_totals as (select coalesce(sum(weight),0) total_weight from req),
  scored as (
    select cp.profile_id candidate_id,j.city job_city,j.salary_min,j.salary_max,j.shift,cp.city candidate_city,cp.desired_salary,
      coalesce(tp.preferred_shifts,'{}'::text[]) preferred_shifts,
      coalesce(sum(case when cs.skill_id is not null and cs.proficiency >= r.min_proficiency and (cs.verified or cs.source_type in ('evidencia','desafio','avaliacao','outcome')) then r.weight else 0 end),0) covered_weight,
      coalesce(sum(case when cs.skill_id is not null and cs.proficiency > 0 then least((least(cs.proficiency::numeric,greatest(r.min_proficiency,1))/greatest(r.min_proficiency,1))*case when cs.verified then 1.0 when cs.source_type='curriculo' then greatest(coalesce(cs.source_confidence,0.6),0.35)*0.60 when cs.source_type='manual' then 0.70 when cs.source_type in ('evidencia','desafio','avaliacao','outcome') then 0.90 else 0.50 end,1)*r.weight else 0 end),0) effective_weight,
      coalesce(sum(case when cs.skill_id is not null and cs.verified then r.weight else 0 end),0) verified_weight,
      coalesce(sum(case when cs.skill_id is not null and cs.source_type='curriculo' then r.weight else 0 end),0) resume_weight,
      coalesce(sum(case when cs.skill_id is not null and cs.proficiency >= r.min_proficiency then r.weight else 0 end),0) declared_coverage_weight,
      coalesce(jsonb_agg(jsonb_build_object('skill',r.name,'required_level',r.min_proficiency,'candidate_level',coalesce(cs.proficiency,0),'verified',coalesce(cs.verified,false),'source',coalesce(cs.source_type,'ausente')) order by r.name) filter(where cs.skill_id is null or cs.proficiency<r.min_proficiency or not cs.verified),'[]'::jsonb) gaps
    from public.candidate_profiles cp cross join public.jobs j cross join req r
    left join public.candidate_skills cs on cs.candidate_id=cp.profile_id and cs.skill_id=r.skill_id
    left join public.talent_preferences tp on tp.candidate_id=cp.profile_id
    where j.id=p_job_id and cp.profile_id=p_candidate_id and cp.searchable and cp.visibility_consent_at is not null
    group by cp.profile_id,j.city,j.salary_min,j.salary_max,j.shift,cp.city,cp.desired_salary,tp.preferred_shifts
  ), calc as (
    select s.*,case when rt.total_weight=0 then 0 else greatest(0,least(1,s.effective_weight/rt.total_weight)) end capability_ratio,
      case when rt.total_weight=0 then 0 else greatest(0,least(1,s.covered_weight/rt.total_weight)) end verified_coverage_ratio,
      case when rt.total_weight=0 then 0 else greatest(0,least(1,s.verified_weight/rt.total_weight)) end verified_ratio,
      case when rt.total_weight=0 then 0 else greatest(0,least(1,s.resume_weight/rt.total_weight)) end resume_ratio,
      case when rt.total_weight=0 then 0 else greatest(0,least(1,s.declared_coverage_weight/rt.total_weight)) end declared_ratio,
      case when s.shift is null or s.preferred_shifts='{}'::text[] then 0.5 when s.shift=any(s.preferred_shifts) then 1 else 0 end shift_ratio,
      case when lower(coalesce(s.candidate_city,''))=lower(coalesce(s.job_city,'')) and coalesce(s.candidate_city,'')<>'' then 1 else 0 end city_ratio,
      case when s.desired_salary is null then 0.5 when s.salary_min is null and s.salary_max is null then 0.5 when s.salary_min is not null and s.salary_max is not null and s.desired_salary between s.salary_min and s.salary_max then 1 when s.salary_min is not null and s.desired_salary>=s.salary_min and s.salary_max is null then 1 when s.salary_max is not null and s.desired_salary<=s.salary_max and s.salary_min is null then 1 else 0 end salary_ratio
    from scored s cross join req_totals rt
  ), final as (
    select c.candidate_id,round(100*(0.60*c.capability_ratio+0.10*c.verified_coverage_ratio+0.15*c.verified_ratio+0.05*c.shift_ratio+0.025*c.city_ratio+0.025*c.salary_ratio),2) score,
      jsonb_build_array(
        case when c.capability_ratio>=0.999 then 'Capacidade efetiva cobre os requisitos' when c.declared_ratio>c.capability_ratio+0.05 then 'Há skills declaradas que ainda não têm comprovação equivalente' when c.capability_ratio>0 then 'Parte da capacidade necessária está sustentada por skills do candidato' else 'Cobertura de capacidade baixa' end,
        case when c.verified_ratio>=0.999 then 'Evidências verificadas nas skills obrigatórias' when c.verified_ratio>0 then 'Há evidências verificadas em parte das skills' else 'Nenhuma skill obrigatória está verificada' end,
        case when c.resume_ratio>0 then 'Parte das skills veio do currículo e foi tratada como não verificada' else 'Skills consideradas não dependem de currículo importado' end,
        case when c.shift_ratio=1 then 'Preferência de turno compatível' when c.shift_ratio=0.5 then 'Turno sem preferência informada' else 'Turno fora da preferência' end,
        case when c.city_ratio=1 then 'Mesma cidade da vaga' else 'Cidade diferente da vaga' end,
        case when c.salary_ratio=1 then 'Pretensão dentro da faixa' when c.salary_ratio=0.5 then 'Pretensão salarial não informada ou faixa incompleta' else 'Pretensão fora da faixa' end
      ) reasons,c.gaps from calc c
  )
  select p_job_id,f.candidate_id,f.score,f.reasons,f.gaps from final f
  on conflict(job_id,candidate_id) do update
  set score=excluded.score,reasons=excluded.reasons,gaps=excluded.gaps,created_at=now();

end $$;
revoke all on function private.refresh_candidate_job(uuid,uuid) from public,anon,authenticated;

-- A single scoring implementation also serves recruiter-requested refreshes.
create or replace function public.generate_matches_for_job(p_job_id uuid)
returns table(candidate_id uuid,score numeric,reasons jsonb,gaps jsonb)
language plpgsql security invoker set search_path='' as $$
begin
 return query select * from private.generate_job_matches(p_job_id);
end $$;
create or replace function private.generate_job_matches(p_job_id uuid)
returns table(candidate_id uuid,score numeric,reasons jsonb,gaps jsonb)
language plpgsql security definer set search_path='' as $$
declare c record;
begin
 if auth.uid() is null or not (coalesce(private.is_admin(),false) or exists (
   select 1 from public.jobs j join public.company_members cm on cm.company_id=j.company_id
   where j.id=p_job_id and cm.user_id=auth.uid() and cm.member_role in ('owner','recruiter')
 )) then raise exception 'not authorized for this job'; end if;
 if not exists(select 1 from public.jobs where id=p_job_id) then raise exception 'job not found'; end if;
 delete from public.matches m where m.job_id=p_job_id and not exists (
   select 1 from public.candidate_profiles cp where cp.profile_id=m.candidate_id and cp.searchable and cp.visibility_consent_at is not null
 );
 for c in select profile_id from public.candidate_profiles where searchable and visibility_consent_at is not null loop
   perform private.refresh_candidate_job(c.profile_id,p_job_id);
 end loop;
 update public.jobs j set qualified_candidate_at=coalesce(j.qualified_candidate_at,now())
 where j.id=p_job_id and exists(select 1 from public.matches m where m.job_id=p_job_id and m.score>=80);
 return query select m.candidate_id,m.score,m.reasons,m.gaps from public.matches m where m.job_id=p_job_id order by m.score desc;
end $$;
revoke all on function private.generate_job_matches(uuid) from public,anon;
grant execute on function private.generate_job_matches(uuid) to authenticated;

create or replace function private.refresh_skill_opportunities()
returns trigger language plpgsql security definer set search_path='' as $$
declare j record; v_candidate uuid; v_skill uuid; v_level smallint;
begin
 if auth.uid() is null then raise exception 'authentication required'; end if;
 if tg_op='DELETE' then v_candidate:=old.candidate_id; v_skill:=old.skill_id; v_level:=0;
 else v_candidate:=new.candidate_id; v_skill:=new.skill_id; v_level:=new.proficiency; end if;
 for j in select distinct jobs.id from public.jobs jobs join public.job_skills js on js.job_id=jobs.id
   where js.skill_id=v_skill and jobs.status='aberta'
 loop perform private.refresh_candidate_job(v_candidate,j.id); end loop;
 perform set_config('talentos.training_generation','1',true);
 update public.training_recommendations tr set current_proficiency=v_level,updated_at=now(),
   status=case when v_level>=tr.target_proficiency and exists (
     select 1 from public.candidate_skills cs where cs.candidate_id=v_candidate and cs.skill_id=v_skill
       and (cs.verified or cs.source_type in ('evidencia','desafio','avaliacao','outcome'))
   ) then 'resolvido' when tr.status='resolvido' then 'recomendado' else tr.status end
 where tr.candidate_id=v_candidate and tr.skill_id=v_skill and tr.status in ('recomendado','em_andamento','resolvido');
 perform set_config('talentos.training_generation','',true);
 if tg_op='DELETE' then return old; end if;
 return new;
end $$;
revoke all on function private.refresh_skill_opportunities() from public,anon,authenticated;
create trigger candidate_skill_refresh after insert or update of proficiency,verified,source_type,source_confidence or delete
 on public.candidate_skills for each row execute function private.refresh_skill_opportunities();

create or replace function private.apply_reviewed_skill_evidence(p_evidence_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare e public.skill_evidence; cs public.candidate_skills; v_level smallint; v_cap smallint;
 v_confidence numeric; v_source text; v_event uuid; v_before smallint;
begin
 if auth.uid() is null then raise exception 'authentication required'; end if;
 select * into e from public.skill_evidence where id=p_evidence_id for update;
 if not found or not (e.candidate_id=auth.uid() or coalesce(private.is_admin(),false) or exists (
   select 1 from public.applications a join public.jobs j on j.id=a.job_id
   join public.company_members cm on cm.company_id=j.company_id
   where a.candidate_id=e.candidate_id and cm.user_id=auth.uid() and cm.member_role in ('owner','recruiter')
 )) then raise exception 'not authorized'; end if;
 if e.validation_status<>'aprovada' or not e.verified or e.reviewed_by is null or e.reviewed_by=e.candidate_id
    or (e.expires_at is not null and e.expires_at<=now()) then
   return jsonb_build_object('status','aguardando_validacao','applied',false);
 end if;
 if not exists(select 1 from public.evidence_reviews r where r.evidence_id=e.id and r.reviewer_id=e.reviewed_by and r.to_status='aprovada') then
   return jsonb_build_object('status','sem_revisao_auditavel','applied',false);
 end if;
 if exists(select 1 from public.candidate_skill_events where evidence_id=e.id) then
   return jsonb_build_object('status','ja_aplicada','applied',false);
 end if;
 -- Lock candidate profile to serialize distinct evidence for the same passport.
 perform 1 from public.candidate_profiles where profile_id=e.candidate_id for update;
 select * into cs from public.candidate_skills where candidate_id=e.candidate_id and skill_id=e.skill_id for update;
 v_before:=coalesce(cs.proficiency,0);
 v_source:=case e.evidence_type when 'desafio' then 'desafio' when 'avaliacao' then 'avaliacao' else 'evidencia' end;
 v_cap:=case when e.evidence_type in ('desafio','avaliacao') then 3 else 2 end;
 v_confidence:=case when e.evidence_type in ('desafio','avaliacao') then 0.85 when e.evidence_type='certificado' then 0.75 else 0.65 end;
 v_level:=greatest(v_before,least(v_before+1,v_cap));
 insert into public.candidate_skills(candidate_id,skill_id,proficiency,verified,source_type,source_confidence,source_excerpt)
 values(e.candidate_id,e.skill_id,v_level,false,v_source,v_confidence,'Evidência revisada: '||left(e.title,400))
 on conflict(candidate_id,skill_id) do update set
  proficiency=greatest(public.candidate_skills.proficiency,excluded.proficiency),
  source_type=case when coalesce(public.candidate_skills.source_confidence,0)>v_confidence then public.candidate_skills.source_type else excluded.source_type end,
  source_confidence=greatest(coalesce(public.candidate_skills.source_confidence,0),v_confidence),
  source_excerpt=case when coalesce(public.candidate_skills.source_confidence,0)>v_confidence then public.candidate_skills.source_excerpt else excluded.source_excerpt end;
 -- Deliberately does not change verified. Human review owns verification.
 insert into public.candidate_skill_events(candidate_id,skill_id,evidence_id,previous_proficiency,new_proficiency,confidence,source_type,explanation,actor_id)
 values(e.candidate_id,e.skill_id,e.id,v_before,v_level,v_confidence,v_source,
   'Revisão humana; avanço máximo de um nível, limite '||v_cap||'. Sem regressão e sem reaplicar a mesma evidência.',auth.uid()) returning id into v_event;
 insert into public.audit_events(actor_id,action,entity_type,entity_id,metadata)
 values(auth.uid(),'skill_evidence_applied','candidate_skill_events',v_event,
   jsonb_build_object('candidate_id',e.candidate_id,'skill_id',e.skill_id,'evidence_id',e.id,'before',v_before,'after',v_level,'policy','reviewed-evidence-v1'));
 return jsonb_build_object('status','aplicada','applied',true,'previous_proficiency',v_before,'proficiency',v_level,'confidence',v_confidence);
end $$;
revoke all on function private.apply_reviewed_skill_evidence(uuid) from public,anon;
grant execute on function private.apply_reviewed_skill_evidence(uuid) to authenticated;
create or replace function public.apply_skill_evidence(p_evidence_id uuid)
returns jsonb language sql security invoker set search_path='' as $$
 select private.apply_reviewed_skill_evidence(p_evidence_id);
$$;
revoke all on function public.apply_skill_evidence(uuid) from public,anon;
grant execute on function public.apply_skill_evidence(uuid) to authenticated;

-- Review must authorize inside the database, including administrators; self-review is forbidden.
create or replace function private.review_skill_evidence(p_evidence_id uuid,p_status text,p_note text)
returns public.skill_evidence language plpgsql security definer set search_path='' as $$
declare v_old public.skill_evidence; v_new public.skill_evidence;
begin
 if auth.uid() is null then raise exception 'authentication required'; end if;
 if p_status is null or p_status not in ('aprovada','reprovada') then raise exception 'invalid validation status'; end if;
 select * into v_old from public.skill_evidence where id=p_evidence_id for update;
 if not found or v_old.candidate_id=auth.uid() or not (coalesce(private.is_admin(),false) or exists (
   select 1 from public.applications a join public.jobs j on j.id=a.job_id
   join public.company_members cm on cm.company_id=j.company_id
   where a.candidate_id=v_old.candidate_id and cm.user_id=auth.uid() and cm.member_role in ('owner','recruiter')
 )) then raise exception 'not authorized to review evidence'; end if;
 perform set_config('talentos.reviewing','1',true);
 update public.skill_evidence set validation_status=p_status,verified=(p_status='aprovada'),
 verified_at=case when p_status='aprovada' then now() else null end,
 reviewed_by=auth.uid(),reviewed_at=now(),review_note=nullif(trim(p_note),'')
 where id=p_evidence_id returning * into v_new;
 insert into public.evidence_reviews(evidence_id,reviewer_id,from_status,to_status,note)
 values(p_evidence_id,auth.uid(),v_old.validation_status,p_status,nullif(trim(p_note),''));
 if p_status='aprovada' then perform private.apply_reviewed_skill_evidence(p_evidence_id); end if;
 update public.candidate_skills cs set verified=exists(
  select 1 from public.skill_evidence se where se.candidate_id=cs.candidate_id and se.skill_id=cs.skill_id
    and se.validation_status='aprovada' and se.reviewed_by is not null and se.reviewed_by<>se.candidate_id
    and (se.expires_at is null or se.expires_at>now())
 ) where cs.candidate_id=v_new.candidate_id and cs.skill_id=v_new.skill_id;
 perform set_config('talentos.reviewing','',true);
 insert into public.audit_events(actor_id,action,entity_type,entity_id,metadata)
 values(auth.uid(),'evidence_reviewed','skill_evidence',p_evidence_id,jsonb_build_object('status',p_status));
 return v_new;
end $$;
revoke all on function private.review_skill_evidence(uuid,text,text) from public,anon;
grant execute on function private.review_skill_evidence(uuid,text,text) to authenticated;
create or replace function public.review_skill_evidence(p_evidence_id uuid,p_status text,p_note text default null)
returns public.skill_evidence language sql security invoker set search_path='' as $$
 select private.review_skill_evidence(p_evidence_id,p_status,p_note);
$$;
revoke all on function public.review_skill_evidence(uuid,text,text) from public,anon;
grant execute on function public.review_skill_evidence(uuid,text,text) to authenticated;
-- Direct mutation cannot bypass the review RPC, even by setting a custom flag.
revoke update on public.skill_evidence from authenticated;
revoke insert,update,delete on public.evidence_reviews from authenticated;
revoke all on public.candidate_skill_events from anon;
