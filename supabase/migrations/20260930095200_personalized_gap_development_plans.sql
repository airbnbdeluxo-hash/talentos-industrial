-- TalentOS: personalized gap-to-development plans
alter table public.training_recommendations
  add column if not exists development_plan jsonb not null default '{}'::jsonb;

create index if not exists training_recommendations_candidate_status_idx
  on public.training_recommendations(candidate_id,status,priority);

create or replace function public.generate_training_plan_for_job(
  p_candidate_id uuid,
  p_job_id uuid
)
returns setof public.training_recommendations
language plpgsql
set search_path to 'public'
as $function$
declare
  actor uuid := (select auth.uid());
  req record;
  gap_kind text;
  gap_reason text;
  gap_priority smallint;
  gap_hours numeric(6,1);
  source_label text;
  evidence_state text;
  gap_size smallint;
  plan jsonb;
begin
  if actor is null then raise exception 'Autenticação obrigatória'; end if;
  if not exists(select 1 from public.candidate_profiles cp where cp.profile_id=p_candidate_id) then
    raise exception 'Candidato não encontrado';
  end if;
  if not exists(select 1 from public.jobs j where j.id=p_job_id) then
    raise exception 'Vaga não encontrada'; end if;

  if actor <> p_candidate_id
     and not exists (
       select 1 from public.jobs j
       join public.company_members cm on cm.company_id=j.company_id
       where j.id=p_job_id and cm.user_id=actor
         and cm.member_role in ('owner','recruiter')
     )
     and not private.is_admin()
  then raise exception 'Sem permissão para gerar plano'; end if;

  perform set_config('talentos.training_generation','1',true);

  for req in
    select js.skill_id,s.name skill_name,s.category skill_category,parent.name parent_skill_name,
           coalesce(js.min_proficiency,3) target_level,coalesce(js.weight,1) skill_weight,
           cs.proficiency current_level,cs.verified,cs.source_type,
           coalesce(cs.source_confidence,0) source_confidence
    from public.job_skills js
    join public.skills s on s.id=js.skill_id
    left join public.skills parent on parent.id=s.parent_skill_id
    left join public.candidate_skills cs
      on cs.candidate_id=p_candidate_id and cs.skill_id=js.skill_id
    where js.job_id=p_job_id and coalesce(js.required,true)
      and (cs.skill_id is null or coalesce(cs.proficiency,0) < coalesce(js.min_proficiency,3))
    order by js.weight desc nulls last,js.skill_id
  loop
    if req.current_level is null then
      gap_kind:='ausente'; gap_size:=req.target_level;
      gap_reason:=format('A vaga exige %s no nível %s; a competência ainda não está declarada no Skill Passport.',req.skill_name,req.target_level);
      gap_hours:=greatest(16,req.target_level*8); source_label:='ausente'; evidence_state:='sem evidência declarada';
    else
      gap_kind:='nivel'; gap_size:=greatest(req.target_level-req.current_level,1);
      gap_reason:=format('A vaga exige %s no nível %s; o nível atual é %s. O plano foca a evolução do nível %s para %s.',req.skill_name,req.target_level,req.current_level,req.current_level,req.target_level);
      gap_hours:=greatest(8,gap_size*8); source_label:=coalesce(req.source_type,'manual');
      evidence_state:=case
        when req.verified then 'verificada'
        when req.source_type in ('evidencia','desafio','avaliacao','outcome') then 'evidência forte não verificada'
        when req.source_type='curriculo' then 'extraída do currículo e ainda não verificada'
        else 'declarada e ainda não verificada'
      end;
    end if;

    gap_priority:=least(5,greatest(1,6-least(3,gap_size)
      -case when req.skill_weight>=2 then 1 else 0 end
      +case when req.current_level is null then 1 when req.verified then 0
            when req.source_type in ('evidencia','desafio','avaliacao','outcome') then 0 else 1 end));

    plan:=jsonb_build_object(
      'version',1,
      'skill',jsonb_build_object('id',req.skill_id,'name',req.skill_name,'category',req.skill_category,'parent',req.parent_skill_name),
      'objective',jsonb_build_object('from_level',coalesce(req.current_level,0),'target_level',req.target_level,'gap_size',gap_size),
      'evidence',jsonb_build_object('state',evidence_state,'source_type',source_label,'source_confidence',req.source_confidence,'verified',coalesce(req.verified,false)),
      'steps',jsonb_build_array(
        jsonb_build_object('order',1,'type','fundamentos','title',format('Revisar fundamentos de %s',req.skill_name),'estimated_hours',greatest(2,round(gap_hours*0.25,1))),
        jsonb_build_object('order',2,'type','pratica','title',format('Praticar %s em contexto industrial',req.skill_name),'estimated_hours',greatest(2,round(gap_hours*0.45,1))),
        jsonb_build_object('order',3,'type','desafio','title',format('Concluir desafio prático de %s',req.skill_name),'estimated_hours',greatest(1,round(gap_hours*0.20,1))),
        jsonb_build_object('order',4,'type','validacao','title',format('Validar proficiência alvo de %s',req.skill_name),'estimated_hours',greatest(1,round(gap_hours*0.10,1)))
      )
    );

    insert into public.training_recommendations(
      candidate_id,job_id,skill_id,priority,reason,estimated_hours,status,gap_type,
      current_proficiency,target_proficiency,development_plan,updated_at
    )
    values(p_candidate_id,p_job_id,req.skill_id,gap_priority,gap_reason,gap_hours,'recomendado',
           gap_kind,req.current_level,req.target_level,plan,now())
    on conflict(candidate_id,job_id,skill_id) do update set
      priority=excluded.priority,reason=excluded.reason,estimated_hours=excluded.estimated_hours,
      gap_type=excluded.gap_type,current_proficiency=excluded.current_proficiency,
      target_proficiency=excluded.target_proficiency,development_plan=excluded.development_plan,
      updated_at=now(),
      status=case when public.training_recommendations.status in ('dispensado','resolvido')
                  then 'recomendado' else public.training_recommendations.status end;
  end loop;

  update public.training_recommendations tr
  set status='resolvido',updated_at=now()
  where tr.candidate_id=p_candidate_id and tr.job_id=p_job_id
    and tr.status in ('recomendado','em_andamento')
    and not exists(
      select 1 from public.job_skills js
      left join public.candidate_skills cs
        on cs.candidate_id=p_candidate_id and cs.skill_id=js.skill_id
      where js.job_id=p_job_id and js.skill_id=tr.skill_id and coalesce(js.required,true)
        and (cs.skill_id is null or coalesce(cs.proficiency,0)<coalesce(js.min_proficiency,3))
    );

  return query
    select * from public.training_recommendations
    where candidate_id=p_candidate_id and job_id=p_job_id
    order by status,priority,created_at;
end;
$function$;
