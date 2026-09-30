create table if not exists public.training_resources (
  id uuid primary key default gen_random_uuid(),
  skill_id uuid references public.skills(id) on delete set null,
  capability_node_id uuid references public.capability_nodes(id) on delete set null,
  title text not null,
  description text,
  resource_type text not null default 'curso' check (resource_type in ('curso','artigo','video','simulacao','desafio','projeto','material')),
  provider text not null,
  url text not null,
  duration_minutes integer check (duration_minutes is null or duration_minutes > 0),
  difficulty text not null default 'basico' check (difficulty in ('basico','intermediario','avancado')),
  active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists training_resources_skill_idx on public.training_resources(skill_id, active);
create index if not exists training_resources_capability_idx on public.training_resources(capability_node_id, active);

create table if not exists public.training_plan_resources (
  recommendation_id uuid not null references public.training_recommendations(id) on delete cascade,
  resource_id uuid not null references public.training_resources(id) on delete cascade,
  step_order smallint not null default 1 check (step_order between 1 and 10),
  mandatory boolean not null default false,
  reason text,
  created_at timestamptz not null default now(),
  primary key (recommendation_id, resource_id)
);
create index if not exists training_plan_resources_resource_idx on public.training_plan_resources(resource_id);

alter table public.training_resources enable row level security;
alter table public.training_plan_resources enable row level security;

grant select on public.training_resources to authenticated;
grant select on public.training_plan_resources to authenticated;

drop policy if exists training_resources_authenticated_select on public.training_resources;
create policy training_resources_authenticated_select on public.training_resources
for select to authenticated using (active = true);

drop policy if exists training_plan_resources_candidate_select on public.training_plan_resources;
create policy training_plan_resources_candidate_select on public.training_plan_resources
for select to authenticated
using (
  exists (
    select 1 from public.training_recommendations tr
    where tr.id = training_plan_resources.recommendation_id
      and tr.candidate_id = (select auth.uid())
  )
);

drop policy if exists training_plan_resources_company_select on public.training_plan_resources;
create policy training_plan_resources_company_select on public.training_plan_resources
for select to authenticated
using (
  exists (
    select 1
    from public.training_recommendations tr
    join public.jobs j on j.id = tr.job_id
    join public.company_members cm on cm.company_id = j.company_id
    where tr.id = training_plan_resources.recommendation_id
      and cm.user_id = (select auth.uid())
  )
);

create or replace function public.get_training_plan_resources(p_recommendation_id uuid)
returns table (
  resource_id uuid, title text, description text, resource_type text, provider text,
  url text, duration_minutes integer, difficulty text, step_order smallint,
  mandatory boolean, reason text
)
language sql security invoker stable
as $$
  select r.id,r.title,r.description,r.resource_type,r.provider,r.url,r.duration_minutes,
         r.difficulty,tpr.step_order,tpr.mandatory,tpr.reason
  from public.training_plan_resources tpr
  join public.training_resources r on r.id=tpr.resource_id
  where tpr.recommendation_id=p_recommendation_id and r.active=true
  order by tpr.step_order,r.duration_minutes nulls last,r.title;
$$;
grant execute on function public.get_training_plan_resources(uuid) to authenticated;

create or replace function public.attach_training_resources(p_recommendation_id uuid)
returns integer
language plpgsql security invoker
as $$
declare
  rec public.training_recommendations%rowtype;
  added integer := 0;
begin
  select * into rec from public.training_recommendations where id=p_recommendation_id;
  if not found then raise exception 'recommendation not found'; end if;

  if rec.candidate_id <> (select auth.uid()) and not exists (
    select 1 from public.jobs j
    join public.company_members cm on cm.company_id=j.company_id
    where j.id=rec.job_id and cm.user_id=(select auth.uid())
  ) then
    raise exception 'not authorized';
  end if;

  insert into public.training_plan_resources(
    recommendation_id,resource_id,step_order,mandatory,reason
  )
  select rec.id,r.id,
    case when r.resource_type in ('curso','material') then 2
         when r.resource_type in ('desafio','projeto','simulacao') then 4 else 3 end,
    r.resource_type in ('curso','desafio'),
    case when r.capability_node_id is not null
         then 'Recurso conectado ao SkillGraph.'
         else 'Recurso relacionado à competência em lacuna.' end
  from public.training_resources r
  where r.active
    and (
      r.skill_id=rec.skill_id
      or exists (
        select 1 from public.capability_nodes cn
        where cn.id=r.capability_node_id and cn.skill_id=rec.skill_id
      )
    )
  order by case when r.resource_type='curso' then 1
                when r.resource_type='material' then 2
                when r.resource_type='desafio' then 3 else 4 end,
           r.duration_minutes nulls last
  limit 5
  on conflict do nothing;

  get diagnostics added = row_count;
  return added;
end;
$$;
grant execute on function public.attach_training_resources(uuid) to authenticated;

insert into public.training_resources(
  skill_id,title,description,resource_type,provider,url,duration_minutes,difficulty,metadata
)
select s.id,x.title,x.description,x.resource_type,'SENAI-RS',x.url,x.duration_minutes,x.difficulty,
       jsonb_build_object('source','catalogo_oficial','reviewed_at',current_date)
from (values
 ('CNC','Catálogo SENAI-RS · Metalmecânica','Pesquise formações e aperfeiçoamentos de manufatura e operação industrial.','curso','https://cursos.senairs.org.br/cursos/',null::integer,'intermediario'),
 ('Metrologia','Catálogo SENAI-RS · Metalmecânica','Catálogo oficial para localizar cursos relacionados a medição e controle dimensional.','curso','https://cursos.senairs.org.br/cursos/',null::integer,'intermediario'),
 ('Desenho Técnico','Catálogo SENAI-RS · Metalmecânica','Catálogo oficial para localizar cursos relacionados a leitura e interpretação técnica.','curso','https://cursos.senairs.org.br/cursos/',null::integer,'basico'),
 ('Usinagem','Catálogo SENAI-RS · Metalmecânica','Catálogo oficial com formações profissionais ligadas à manufatura e usinagem.','curso','https://cursos.senairs.org.br/cursos/',null::integer,'intermediario'),
 ('Mecânica','Catálogo SENAI-RS · Manutenção e Operação','Catálogo oficial para formação e aperfeiçoamento em manutenção e operação.','curso','https://cursos.senairs.org.br/cursos/',null::integer,'intermediario'),
 ('Elétrica','Catálogo SENAI-RS · Eletrônica e Automação','Catálogo oficial para localizar cursos de elétrica e automação industrial.','curso','https://cursos.senairs.org.br/cursos/',null::integer,'intermediario'),
 ('Pneumática','Catálogo SENAI-RS · Manutenção e Operação','Catálogo oficial para localizar formação relacionada a sistemas pneumáticos.','curso','https://cursos.senairs.org.br/cursos/',null::integer,'intermediario'),
 ('MIG/MAG','Catálogo SENAI-RS · Soldagem','Catálogo oficial com formações de soldagem e processos industriais.','curso','https://cursos.senairs.org.br/cursos/',null::integer,'intermediario'),
 ('TIG','Catálogo SENAI-RS · Soldagem','Catálogo oficial com formações de soldagem e processos industriais.','curso','https://cursos.senairs.org.br/cursos/',null::integer,'intermediario')
) as x(skill_name,title,description,resource_type,url,duration_minutes,difficulty)
join public.skills s on lower(s.name)=lower(x.skill_name)
where not exists (
  select 1 from public.training_resources r where r.skill_id=s.id and r.title=x.title
);

insert into public.training_resources(
  capability_node_id,title,description,resource_type,provider,url,difficulty,metadata
)
select cn.id,'SENAI-RS · Formação profissional conectada ao setor industrial',
       'Ponto de entrada para cursos e programas que podem complementar a trilha desta capacidade.',
       'curso','SENAI-RS','https://www.senairs.org.br/cursos/cursos','intermediario',
       jsonb_build_object('source','catalogo_oficial','reviewed_at',current_date)
from public.capability_nodes cn
where cn.node_type in ('processo','competencia')
and not exists (
  select 1 from public.training_resources r
  where r.capability_node_id=cn.id and r.provider='SENAI-RS'
);