-- TalentOS technical challenge library.
create table if not exists public.challenge_library(
  id uuid primary key default gen_random_uuid(),
  skill_id uuid not null references public.skills(id) on delete cascade,
  title text not null,
  description text not null,
  difficulty text not null default 'basico' check(difficulty in ('basico','intermediario','avancado')),
  time_limit_minutes smallint not null default 10 check(time_limit_minutes between 1 and 180),
  questions jsonb not null default '[]'::jsonb,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.skill_assessments
  add column if not exists challenge_id uuid references public.challenge_library(id) on delete set null,
  add column if not exists attempt_id uuid;

create table if not exists public.challenge_attempts(
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenge_library(id) on delete cascade,
  candidate_id uuid not null references public.candidate_profiles(profile_id) on delete cascade,
  job_id uuid references public.jobs(id) on delete set null,
  status text not null default 'em_andamento' check(status in ('em_andamento','concluido','expirado','cancelado')),
  answers jsonb not null default '{}'::jsonb,
  score numeric(5,2),
  started_at timestamptz not null default now(),
  completed_at timestamptz
);

create index if not exists idx_challenge_library_skill_active on public.challenge_library(skill_id,active);
create index if not exists idx_challenge_attempts_candidate_status on public.challenge_attempts(candidate_id,status);
create index if not exists idx_challenge_attempts_challenge on public.challenge_attempts(challenge_id);
create index if not exists idx_challenge_attempts_job on public.challenge_attempts(job_id);
create index if not exists idx_skill_assessments_challenge on public.skill_assessments(challenge_id);

alter table public.challenge_library enable row level security;
alter table public.challenge_attempts enable row level security;

drop policy if exists challenge_library_read on public.challenge_library;
create policy challenge_library_read on public.challenge_library
for select to authenticated using (active=true);

drop policy if exists challenge_attempts_self_select on public.challenge_attempts;
create policy challenge_attempts_self_select on public.challenge_attempts
for select to authenticated using (candidate_id=(select auth.uid()));

drop policy if exists challenge_attempts_self_insert on public.challenge_attempts;
create policy challenge_attempts_self_insert on public.challenge_attempts
for insert to authenticated with check (candidate_id=(select auth.uid()));

drop policy if exists challenge_attempts_self_update on public.challenge_attempts;
create policy challenge_attempts_self_update on public.challenge_attempts
for update to authenticated
using (candidate_id=(select auth.uid()))
with check (candidate_id=(select auth.uid()));

insert into public.challenge_library(skill_id,title,description,difficulty,time_limit_minutes,questions)
select s.id,'Desafio prático · CNC básico','Avaliação curta de preparação para operação CNC.','basico',8,
'[
 {"id":"q1","text":"Qual item deve ser conferido antes de iniciar uma operação CNC?","options":["Somente a iluminação","Fixação da peça e condição da ferramenta","Apenas o uniforme","Somente a temperatura ambiente"]},
 {"id":"q2","text":"Qual é a função principal do zero-peça?","options":["Definir uma referência de trabalho para o programa","Aumentar automaticamente o avanço","Trocar a ferramenta","Medir o ruído"]},
 {"id":"q3","text":"O que uma leitura de desenho técnico ajuda a definir?","options":["Somente a cor da peça","Dimensões, tolerâncias e características da peça","A escala salarial","O horário do operador"]}
]'::jsonb
from public.skills s where s.name='CNC'
and not exists(select 1 from public.challenge_library c where c.skill_id=s.id and c.title='Desafio prático · CNC básico');

insert into public.challenge_library(skill_id,title,description,difficulty,time_limit_minutes,questions)
select s.id,'Desafio prático · Metrologia','Avaliação curta de fundamentos de medição e tolerância.','basico',8,
'[
 {"id":"q1","text":"Qual instrumento é apropriado para medir uma dimensão externa com precisão?","options":["Paquímetro","Martelo","Chave de boca","Trena de obra"]},
 {"id":"q2","text":"Uma tolerância define:","options":["Apenas a cor da peça","A variação dimensional aceitável","O turno de trabalho","O material do uniforme"]},
 {"id":"q3","text":"Antes de uma medição, uma boa prática é:","options":["Medir sem limpar a superfície","Verificar instrumento e condição de medição","Aquecer a peça com maçarico","Alterar a unidade sem registrar"]}
]'::jsonb
from public.skills s where s.name='Metrologia'
and not exists(select 1 from public.challenge_library c where c.skill_id=s.id and c.title='Desafio prático · Metrologia');

insert into public.challenge_library(skill_id,title,description,difficulty,time_limit_minutes,questions)
select s.id,'Desafio prático · Soldagem MIG/MAG','Avaliação curta de fundamentos de segurança e preparação.','basico',8,
'[
 {"id":"q1","text":"Antes da soldagem, a prioridade é:","options":["Ignorar EPIs","Preparar a área, EPIs e equipamento","Aumentar a velocidade imediatamente","Desligar a ventilação"]},
 {"id":"q2","text":"A preparação da junta influencia principalmente:","options":["A cor da bancada","A qualidade e penetração da solda","O salário","A iluminação"]},
 {"id":"q3","text":"O gás de proteção serve para:","options":["Reduzir a contaminação da poça de fusão","Esfriar o piso","Aumentar o ruído","Substituir o consumível"]}
]'::jsonb
from public.skills s where s.name='MIG/MAG'
and not exists(select 1 from public.challenge_library c where c.skill_id=s.id and c.title='Desafio prático · Soldagem MIG/MAG');

create or replace function public.start_challenge(p_challenge_id uuid,p_job_id uuid default null)
returns uuid
language plpgsql
security invoker
set search_path=public
as $$
declare v_id uuid;
begin
 if (select auth.uid()) is null then raise exception 'authentication required'; end if;
 if not exists(select 1 from public.challenge_library where id=p_challenge_id and active) then raise exception 'challenge not found'; end if;
 insert into public.challenge_attempts(challenge_id,candidate_id,job_id,status)
 values(p_challenge_id,(select auth.uid()),p_job_id,'em_andamento')
 returning id into v_id;
 return v_id;
end;
$$;

revoke all on function public.start_challenge(uuid,uuid) from public,anon;
grant execute on function public.start_challenge(uuid,uuid) to authenticated;

create or replace function public.complete_challenge(p_attempt_id uuid,p_answers jsonb)
returns table(score numeric(5,2),correct_count integer,total_count integer)
language plpgsql
security invoker
set search_path=public
as $$
declare
 v_challenge uuid;
 v_candidate uuid;
 v_job uuid;
 v_questions jsonb;
 v_total integer;
begin
 if (select auth.uid()) is null then raise exception 'authentication required'; end if;

 select ca.challenge_id,ca.candidate_id,ca.job_id,cl.questions
 into v_challenge,v_candidate,v_job,v_questions
 from public.challenge_attempts ca
 join public.challenge_library cl on cl.id=ca.challenge_id
 where ca.id=p_attempt_id and ca.candidate_id=(select auth.uid()) and ca.status='em_andamento';

 if v_candidate is null then raise exception 'attempt not found'; end if;

 v_total=jsonb_array_length(v_questions);

 update public.challenge_attempts
 set answers=p_answers,status='concluido',completed_at=now()
 where id=p_attempt_id and candidate_id=(select auth.uid()) and status='em_andamento';

 insert into public.skill_assessments(candidate_id,job_id,challenge_id,attempt_id,assessment_type,score,status,completed_at)
 values((select auth.uid()),v_job,v_challenge,p_attempt_id,'pratica',null,'concluido',now());

 insert into public.skill_evidence(candidate_id,skill_id,evidence_type,title,issuer,verified,verified_at,score,notes)
 select (select auth.uid()),cl.skill_id,'desafio',cl.title,'TalentOS Challenge',false,null,null,
        'Avaliação concluída e aguardando validação humana.'
 from public.challenge_library cl where cl.id=v_challenge;

 return query select null::numeric(5,2),null::integer,v_total;
end;
$$;

revoke all on function public.complete_challenge(uuid,jsonb) from public,anon;
grant execute on function public.complete_challenge(uuid,jsonb) to authenticated;