-- TalentOS: SkillGraph-guided development plans
alter table public.training_recommendations
  add column if not exists graph_context jsonb not null default '{}'::jsonb;
create index if not exists training_recommendations_skill_graph_idx
  on public.training_recommendations(skill_id,priority);

create or replace function public.generate_training_plan_for_job(
  p_candidate_id uuid,p_job_id uuid
) returns setof public.training_recommendations
language plpgsql set search_path to 'public'
as $function$
declare actor uuid := auth.uid(); req record; graph jsonb; gap_kind text; gap_reason text;
gap_priority smallint; gap_hours numeric(6,1); source_label text; evidence_state text; gap_size smallint; plan jsonb;
begin
if actor is null then raise exception 'Autenticação obrigatória'; end if;
if not exists(select 1 from candidate_profiles where profile_id=p_candidate_id) then raise exception 'Candidato não encontrado'; end if;
if not exists(select 1 from jobs where id=p_job_id) then raise exception 'Vaga não encontrada'; end if;
if actor<>p_candidate_id and not exists(select 1 from jobs j join company_members cm on cm.company_id=j.company_id where j.id=p_job_id and cm.user_id=actor and cm.member_role in ('owner','recruiter')) and not private.is_admin() then raise exception 'Sem permissão para gerar plano'; end if;
perform set_config('talentos.training_generation','1',true);

for req in
select js.skill_id,s.name skill_name,s.category skill_category,parent.name parent_skill_name,
coalesce(js.min_proficiency,3) target_level,coalesce(js.weight,1) skill_weight,
cs.proficiency current_level,cs.verified,cs.source_type,coalesce(cs.source_confidence,0) source_confidence
from job_skills js join skills s on s.id=js.skill_id
left join skills parent on parent.id=s.parent_skill_id
left join candidate_skills cs on cs.candidate_id=p_candidate_id and cs.skill_id=js.skill_id
where js.job_id=p_job_id and coalesce(js.required,true) and (cs.skill_id is null or coalesce(cs.proficiency,0)<coalesce(js.min_proficiency,3))
order by js.weight desc nulls last,js.skill_id
loop
if req.current_level is null then gap_kind:='ausente';gap_size:=req.target_level;gap_reason:=format('A vaga exige %s no nível %s; a competência ainda não está declarada no Skill Passport.',req.skill_name,req.target_level);gap_hours:=greatest(16,req.target_level*8);source_label:='ausente';evidence_state:='sem evidência declarada';
else gap_kind:='nivel';gap_size:=greatest(req.target_level-req.current_level,1);gap_reason:=format('A vaga exige %s no nível %s; o nível atual é %s. O plano foca a evolução do nível %s para %s.',req.skill_name,req.target_level,req.current_level,req.current_level,req.target_level);gap_hours:=greatest(8,gap_size*8);source_label:=coalesce(req.source_type,'manual');evidence_state:=case when req.verified then 'verificada' when req.source_type in ('evidencia','desafio','avaliacao','outcome') then 'evidência forte não verificada' when req.source_type='curriculo' then 'extraída do currículo e ainda não verificada' else 'declarada e ainda não verificada' end; end if;

select coalesce(jsonb_agg(x order by x.depth,x.relationship_type,x.name),'[]'::jsonb) into graph
from (
with recursive prereq as (
select e.from_node_id,e.to_node_id,e.relationship_type,e.weight,1 depth from capability_edges e join capability_nodes target on target.id=e.to_node_id where target.skill_id=req.skill_id and e.relationship_type in ('exige','desenvolve_para','inclui')
union all
select e.from_node_id,e.to_node_id,e.relationship_type,e.weight,p.depth+1 from prereq p join capability_edges e on e.to_node_id=p.from_node_id where p.depth<3 and e.relationship_type in ('exige','desenvolve_para','inclui'))
select distinct p.depth,p.relationship_type,p.weight,n.id,n.name,n.node_type,n.skill_id from prereq p join capability_nodes n on n.id=p.from_node_id
where n.id<>(select id from capability_nodes where skill_id=req.skill_id order by id limit 1) limit 12
) x;

gap_priority:=least(5,greatest(1,6-least(3,gap_size)-case when req.skill_weight>=2 then 1 else 0 end+case when req.current_level is null then 1 when req.verified then 0 when req.source_type in ('evidencia','desafio','avaliacao','outcome') then 0 else 1 end));
if jsonb_array_length(graph)>0 then gap_reason:=gap_reason||format(' O SkillGraph identificou %s pré-requisito(s)/competência(s) relacionada(s) para orientar a sequência.',jsonb_array_length(graph));gap_hours:=gap_hours+least(16,jsonb_array_length(graph)*2);end if;

plan:=jsonb_build_object('version',2,'skill',jsonb_build_object('id',req.skill_id,'name',req.skill_name,'category',req.skill_category,'parent',req.parent_skill_name),'objective',jsonb_build_object('from_level',coalesce(req.current_level,0),'target_level',req.target_level,'gap_size',gap_size),'evidence',jsonb_build_object('state',evidence_state,'source_type',source_label,'source_confidence',req.source_confidence,'verified',coalesce(req.verified,false)),'graph',jsonb_build_object('connected',jsonb_array_length(graph)>0,'related_nodes',graph),'steps',jsonb_build_array(
jsonb_build_object('order',1,'type','prerequisitos','title',case when jsonb_array_length(graph)>0 then 'Consolidar pré-requisitos identificados pelo SkillGraph' else 'Confirmar fundamentos necessários' end,'estimated_hours',greatest(2,round(gap_hours*.20,1))),
jsonb_build_object('order',2,'type','fundamentos','title',format('Revisar fundamentos de %s',req.skill_name),'estimated_hours',greatest(2,round(gap_hours*.20,1))),
jsonb_build_object('order',3,'type','pratica','title',format('Praticar %s em contexto industrial',req.skill_name),'estimated_hours',greatest(2,round(gap_hours*.35,1))),
jsonb_build_object('order',4,'type','desafio','title',format('Concluir desafio prático de %s',req.skill_name),'estimated_hours',greatest(1,round(gap_hours*.15,1))),
jsonb_build_object('order',5,'type','validacao','title',format('Validar proficiência alvo de %s',req.skill_name),'estimated_hours',greatest(1,round(gap_hours*.10,1))));

insert into training_recommendations(candidate_id,job_id,skill_id,priority,reason,estimated_hours,status,gap_type,current_proficiency,target_proficiency,development_plan,graph_context,updated_at)
values(p_candidate_id,p_job_id,req.skill_id,gap_priority,gap_reason,gap_hours,'recomendado',gap_kind,req.current_level,req.target_level,plan,jsonb_build_object('related_nodes',graph),now())
on conflict(candidate_id,job_id,skill_id) do update set priority=excluded.priority,reason=excluded.reason,estimated_hours=excluded.estimated_hours,gap_type=excluded.gap_type,current_proficiency=excluded.current_proficiency,target_proficiency=excluded.target_proficiency,development_plan=excluded.development_plan,graph_context=excluded.graph_context,updated_at=now(),status=case when training_recommendations.status in ('dispensado','resolvido') then 'recomendado' else training_recommendations.status end;
end loop;

update training_recommendations tr set status='resolvido',updated_at=now()
where tr.candidate_id=p_candidate_id and tr.job_id=p_job_id and tr.status in ('recomendado','em_andamento')
and not exists(select 1 from job_skills js left join candidate_skills cs on cs.candidate_id=p_candidate_id and cs.skill_id=js.skill_id where js.job_id=p_job_id and js.skill_id=tr.skill_id and coalesce(js.required,true) and (cs.skill_id is null or coalesce(cs.proficiency,0)<coalesce(js.min_proficiency,3)));

return query select * from training_recommendations where candidate_id=p_candidate_id and job_id=p_job_id order by status,priority,created_at;
end;$function$;