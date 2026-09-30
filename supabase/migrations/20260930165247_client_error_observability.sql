create table if not exists public.client_error_events (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid null references public.profiles(id) on delete set null,
  source text not null check (char_length(source) between 1 and 64),
  error_reference text null check (error_reference is null or char_length(error_reference) <= 64),
  message text not null check (char_length(message) between 1 and 1000),
  path text null check (path is null or char_length(path) <= 256),
  created_at timestamptz not null default now()
);

comment on table public.client_error_events is
  'Sanitized client-side technical errors. Never store resume content, messages, interview answers, credentials, tokens, or other user-provided content.';

alter table public.client_error_events enable row level security;

revoke all on table public.client_error_events from public, anon;
grant insert, select on table public.client_error_events to authenticated;

drop policy if exists client_error_events_insert_own on public.client_error_events;
create policy client_error_events_insert_own
  on public.client_error_events
  for insert
  to authenticated
  with check (
    (select auth.uid()) is not null
    and (select auth.uid()) = actor_id
  );

drop policy if exists client_error_events_admin_read on public.client_error_events;
create policy client_error_events_admin_read
  on public.client_error_events
  for select
  to authenticated
  using ((select private.is_admin()));

create index if not exists client_error_events_actor_created_idx
  on public.client_error_events(actor_id, created_at desc);

create index if not exists client_error_events_created_idx
  on public.client_error_events(created_at desc);
