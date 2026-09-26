create table if not exists public.application_events(
 id uuid primary key default gen_random_uuid(),
 application_id uuid not null references public.applications(id) on delete cascade,
 actor_id uuid references public.profiles(id) on delete set null,
 from_status text,
 to_status text not null,
 note text,
 created_at timestamptz not null default now()
);
create index if not exists idx_application_events_application on public.application_events(application_id,created_at desc);
alter table public.application_events enable row level security;
drop policy if exists "application_events_access" on public.application_events;
create policy "application_events_access" on public.application_events for select to authenticated
using(exists(select 1 from public.applications a where a.id=application_id and (a.candidate_id=(select auth.uid()) or exists(select 1 from public.jobs j join public.company_members cm on cm.company_id=j.company_id where j.id=a.job_id and cm.user_id=(select auth.uid())))));
create or replace function public.log_application_event()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 if tg_op='INSERT' then
  insert into public.application_events(application_id,actor_id,from_status,to_status,note) values(new.id,(select auth.uid()),null,new.status,'Candidatura criada');
 elsif new.status is distinct from old.status then
  insert into public.application_events(application_id,actor_id,from_status,to_status,note) values(new.id,(select auth.uid()),old.status,new.status,null);
 end if;
 return new;
end;
$$;
drop trigger if exists application_event_logger on public.applications;
create trigger application_event_logger after insert or update of status on public.applications for each row execute procedure public.log_application_event();
revoke all on function public.log_application_event() from public;
