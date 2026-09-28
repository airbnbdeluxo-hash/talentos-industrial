-- TalentOS Capability Intelligence v1: proprietary industrial capability graph.
create table public.capability_nodes (
  id uuid primary key default gen_random_uuid(),
  node_type text not null check (node_type in ('familia','processo','maquina','controle','competencia','cargo','contexto')),
  name text not null,
  slug text not null unique,
  skill_id uuid references public.skills(id) on delete set null,
  parent_id uuid references public.capability_nodes(id) on delete set null,
  description text,
  metadata jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.capability_edges (
  from_node_id uuid not null references public.capability_nodes(id) on delete cascade,
  to_node_id uuid not null references public.capability_nodes(id) on delete cascade,
  relationship_type text not null check (relationship_type in ('inclui','exige','usa','aplicada_em','proximo_de','desenvolve_para')),
  weight numeric(5,2) not null default 1 check (weight >= 0 and weight <= 1),
  source text not null default 'TalentOS',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  primary key (from_node_id, to_node_id, relationship_type)
);

create index capability_nodes_skill_idx on public.capability_nodes(skill_id) where skill_id is not null;
create index capability_nodes_parent_idx on public.capability_nodes(parent_id) where parent_id is not null;
create index capability_edges_to_idx on public.capability_edges(to_node_id);
create index capability_edges_type_idx on public.capability_edges(relationship_type);

alter table public.capability_nodes enable row level security;
alter table public.capability_edges enable row level security;

revoke all on public.capability_nodes from anon, authenticated;
revoke all on public.capability_edges from anon, authenticated;
grant select on public.capability_nodes to authenticated;
grant select on public.capability_edges to authenticated;

create policy capability_nodes_read on public.capability_nodes
for select to authenticated
using (active = true);

create policy capability_edges_read on public.capability_edges
for select to authenticated
using (
  exists (
    select 1 from public.capability_nodes n
    where n.id = capability_edges.from_node_id and n.active
  )
  and exists (
    select 1 from public.capability_nodes n
    where n.id = capability_edges.to_node_id and n.active
  )
);

with seeded(node_type,name,slug,description) as (
  values
    ('familia','Usinagem','familia-usinagem','Processos de remoção de material e fabricação de componentes.'),
    ('familia','Metrologia','familia-metrologia','Medição, inspeção e controle dimensional.'),
    ('familia','Manutenção Industrial','familia-manutencao-industrial','Manutenção mecânica, elétrica e pneumática de ativos industriais.'),
    ('familia','Soldagem','familia-soldagem','Processos de união e fabricação por soldagem.'),
    ('familia','Automação Industrial','familia-automacao-industrial','Controle, instrumentação e automação de equipamentos e linhas.'),
    ('processo','CNC','processo-cnc','Operação e preparação de equipamentos CNC.'),
    ('processo','Programação CNC','processo-programacao-cnc','Programação e ajuste de máquinas CNC.'),
    ('processo','Medição Dimensional','processo-medicao-dimensional','Medição e inspeção com instrumentos e métodos dimensionais.'),
    ('processo','Manutenção Mecânica','processo-manutencao-mecanica','Inspeção, diagnóstico e intervenção mecânica.'),
    ('processo','Manutenção Elétrica','processo-manutencao-eletrica','Diagnóstico e intervenção em sistemas elétricos industriais.'),
    ('processo','Pneumática','processo-pneumatica','Montagem, diagnóstico e manutenção de circuitos pneumáticos.'),
    ('processo','Soldagem MIG/MAG','processo-soldagem-mig-mag','Processo de soldagem MIG/MAG em ambiente industrial.'),
    ('processo','Soldagem TIG','processo-soldagem-tig','Processo de soldagem TIG em ambiente industrial.'),
    ('processo','Automação com CLP','processo-automacao-clp','Programação e diagnóstico de controladores lógicos programáveis.'),
    ('maquina','Torno CNC','maquina-torno-cnc','Torno CNC para fabricação de peças rotativas.'),
    ('maquina','Centro de Usinagem','maquina-centro-usinagem','Centro de usinagem CNC para operações de fresamento.'),
    ('maquina','Paquímetro e Micrômetro','maquina-paquimetro-micrometro','Instrumentos dimensionais de uso recorrente na indústria.'),
    ('maquina','Bancada de Soldagem','maquina-bancada-soldagem','Posto de soldagem e equipamentos auxiliares.'),
    ('controle','Fanuc','controle-fanuc','Controlador CNC recorrente em máquinas industriais.'),
    ('controle','Siemens S7-1200','controle-siemens-s7-1200','Família de CLPs Siemens utilizada em automação industrial.'),
    ('cargo','Operador CNC','cargo-operador-cnc','Função operacional em máquinas CNC.'),
    ('cargo','Programador CNC','cargo-programador-cnc','Função de programação, preparação e otimização CNC.'),
    ('cargo','Técnico de Manutenção','cargo-tecnico-manutencao','Função técnica de manutenção industrial.'),
    ('cargo','Soldador','cargo-soldador','Função operacional de soldagem industrial.'),
    ('cargo','Técnico de Automação','cargo-tecnico-automacao','Função técnica de automação e controle industrial.'),
    ('contexto','Metal-mecânico','contexto-metal-mecanico','Contexto industrial de transformação metal-mecânica.'),
    ('contexto','Máquinas e Equipamentos','contexto-maquinas-equipamentos','Fabricação e manutenção de máquinas e equipamentos.'),
    ('contexto','Metalurgia','contexto-metalurgia','Contexto industrial de transformação de metais.')
)
insert into public.capability_nodes(node_type,name,slug,description)
select node_type,name,slug,description from seeded
on conflict (slug) do update set
  node_type=excluded.node_type,
  name=excluded.name,
  description=excluded.description,
  updated_at=now();

insert into public.capability_nodes(node_type,name,slug,skill_id,description)
select 'competencia', s.name, 'competencia-' || s.name,
       s.id,
       'Competência operacional modelada pelo TalentOS.'
from public.skills s
where s.name in ('CNC','Metrologia','Desenho Técnico','Leitura de Instrumentos','Mecânica','Elétrica','CLP','Pneumática','MIG/MAG','TIG','Usinagem')
on conflict (slug) do update set
  skill_id=excluded.skill_id,
  name=excluded.name,
  description=excluded.description,
  updated_at=now();

insert into public.capability_edges(from_node_id,to_node_id,relationship_type,weight)
select f.id, p.id, 'inclui', 1
from (values
  ('familia-usinagem','processo-cnc'),
  ('familia-usinagem','processo-programacao-cnc'),
  ('familia-usinagem','processo-medicao-dimensional'),
  ('familia-metrologia','processo-medicao-dimensional'),
  ('familia-manutencao-industrial','processo-manutencao-mecanica'),
  ('familia-manutencao-industrial','processo-manutencao-eletrica'),
  ('familia-manutencao-industrial','processo-pneumatica'),
  ('familia-soldagem','processo-soldagem-mig-mag'),
  ('familia-soldagem','processo-soldagem-tig'),
  ('familia-automacao-industrial','processo-automacao-clp')
) x(from_slug,to_slug)
join public.capability_nodes f on f.slug=x.from_slug
join public.capability_nodes p on p.slug=x.to_slug
on conflict do nothing;

insert into public.capability_edges(from_node_id,to_node_id,relationship_type,weight)
select p.id, c.id, 'exige', 0.9
from (values
  ('processo-cnc','competencia-CNC'),
  ('processo-cnc','competencia-Metrologia'),
  ('processo-cnc','competencia-Desenho Técnico'),
  ('processo-programacao-cnc','competencia-CNC'),
  ('processo-programacao-cnc','competencia-Usinagem'),
  ('processo-programacao-cnc','competencia-Desenho Técnico'),
  ('processo-medicao-dimensional','competencia-Metrologia'),
  ('processo-medicao-dimensional','competencia-Leitura de Instrumentos'),
  ('processo-manutencao-mecanica','competencia-Mecânica'),
  ('processo-manutencao-eletrica','competencia-Elétrica'),
  ('processo-pneumatica','competencia-Pneumática'),
  ('processo-soldagem-mig-mag','competencia-MIG/MAG'),
  ('processo-soldagem-mig-mag','competencia-Leitura de Instrumentos'),
  ('processo-soldagem-tig','competencia-TIG'),
  ('processo-automacao-clp','competencia-CLP')
) x(process_slug,skill_slug)
join public.capability_nodes p on p.slug=x.process_slug
join public.capability_nodes c on c.slug=x.skill_slug
on conflict do nothing;

insert into public.capability_edges(from_node_id,to_node_id,relationship_type,weight)
select p.id, m.id, 'usa', 0.8
from (values
  ('processo-cnc','maquina-torno-cnc'),
  ('processo-cnc','maquina-centro-usinagem'),
  ('processo-medicao-dimensional','maquina-paquimetro-micrometro'),
  ('processo-soldagem-mig-mag','maquina-bancada-soldagem'),
  ('processo-soldagem-tig','maquina-bancada-soldagem'),
  ('processo-cnc','controle-fanuc'),
  ('processo-programacao-cnc','controle-fanuc'),
  ('processo-automacao-clp','controle-siemens-s7-1200')
) x(process_slug,node_slug)
join public.capability_nodes p on p.slug=x.process_slug
join public.capability_nodes m on m.slug=x.node_slug
on conflict do nothing;

insert into public.capability_edges(from_node_id,to_node_id,relationship_type,weight)
select c.id, p.id, 'exige', 0.85
from (values
  ('cargo-operador-cnc','processo-cnc'),
  ('cargo-programador-cnc','processo-programacao-cnc'),
  ('cargo-tecnico-manutencao','processo-manutencao-mecanica'),
  ('cargo-tecnico-manutencao','processo-manutencao-eletrica'),
  ('cargo-tecnico-manutencao','processo-pneumatica'),
  ('cargo-soldador','processo-soldagem-mig-mag'),
  ('cargo-soldador','processo-soldagem-tig'),
  ('cargo-tecnico-automacao','processo-automacao-clp')
) x(cargo_slug,process_slug)
join public.capability_nodes c on c.slug=x.cargo_slug
join public.capability_nodes p on p.slug=x.process_slug
on conflict do nothing;

insert into public.capability_edges(from_node_id,to_node_id,relationship_type,weight)
select p.id, ctx.id, 'aplicada_em', 0.75
from (values
  ('processo-cnc','contexto-metal-mecanico'),
  ('processo-programacao-cnc','contexto-maquinas-equipamentos'),
  ('processo-manutencao-mecanica','contexto-maquinas-equipamentos'),
  ('processo-manutencao-eletrica','contexto-maquinas-equipamentos'),
  ('processo-soldagem-mig-mag','contexto-metal-mecanico'),
  ('processo-soldagem-tig','contexto-metal-mecanico')
) x(process_slug,ctx_slug)
join public.capability_nodes p on p.slug=x.process_slug
join public.capability_nodes ctx on ctx.slug=x.ctx_slug
on conflict do nothing;

insert into public.capability_edges(from_node_id,to_node_id,relationship_type,weight)
select a.id,b.id,'proximo_de',0.6
from (values
  ('competencia-CNC','competencia-Usinagem'),
  ('competencia-Metrologia','competencia-Leitura de Instrumentos'),
  ('competencia-Mecânica','competencia-Pneumática'),
  ('competencia-Elétrica','competencia-CLP'),
  ('competencia-MIG/MAG','competencia-TIG')
) x(a_slug,b_slug)
join public.capability_nodes a on a.slug=x.a_slug
join public.capability_nodes b on b.slug=x.b_slug
on conflict do nothing;
