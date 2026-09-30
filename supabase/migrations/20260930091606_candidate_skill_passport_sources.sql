alter table public.candidate_skills
  add column if not exists source_type text not null default 'manual',
  add column if not exists source_confidence numeric(4,3),
  add column if not exists source_excerpt text,
  add column if not exists source_resume_id uuid references public.candidate_resumes(id) on delete set null;

alter table public.candidate_skills
  drop constraint if exists candidate_skills_source_type_check;

alter table public.candidate_skills
  add constraint candidate_skills_source_type_check
  check (source_type in ('manual','curriculo','evidencia','desafio','avaliacao','outcome'));

alter table public.candidate_skills
  drop constraint if exists candidate_skills_source_confidence_check;

alter table public.candidate_skills
  add constraint candidate_skills_source_confidence_check
  check (source_confidence is null or (source_confidence >= 0 and source_confidence <= 1));

create index if not exists candidate_skills_source_resume_idx
  on public.candidate_skills(source_resume_id)
  where source_resume_id is not null;
