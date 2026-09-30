-- TalentOS Industrial: screening and notification data layer
alter table public.jobs add column if not exists screening_questions jsonb not null default '[]'::jsonb;
alter table public.applications add column if not exists screening_answers jsonb not null default '{}'::jsonb;
create index if not exists jobs_screening_questions_gin_idx on public.jobs using gin(screening_questions);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null default 'vaga',
  title text not null,
  body text not null,
  href text,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists notifications_user_created_idx on public.notifications(user_id,created_at desc);
alter table public.notifications enable row level security;
