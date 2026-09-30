-- TalentOS Industrial: structured job information
alter table public.jobs add column if not exists employment_type text not null default 'CLT';
alter table public.jobs add column if not exists work_model text not null default 'Presencial';
alter table public.jobs add column if not exists benefits text[] not null default '{}';
alter table public.jobs add column if not exists travel_required boolean not null default false;
