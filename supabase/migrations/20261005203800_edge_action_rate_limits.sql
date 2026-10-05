create table if not exists private.security_rate_limits (
  actor_id uuid not null,
  action text not null check (char_length(action) between 1 and 80),
  window_start timestamptz not null,
  hit_count integer not null default 1 check (hit_count > 0),
  updated_at timestamptz not null default now(),
  primary key (actor_id, action, window_start)
);

revoke all on table private.security_rate_limits from public, anon, authenticated;

create or replace function public.security_rate_limit_consume(
  p_actor_id uuid,
  p_action text,
  p_limit integer,
  p_window_seconds integer
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_window timestamptz;
  v_count integer;
begin
  if p_actor_id is null
     or coalesce(length(trim(p_action)),0) = 0
     or p_limit < 1 or p_limit > 10000
     or p_window_seconds < 10 or p_window_seconds > 86400 then
    raise exception 'invalid rate limit parameters';
  end if;

  v_window := to_timestamp(
    floor(extract(epoch from now()) / p_window_seconds) * p_window_seconds
  );

  insert into private.security_rate_limits(actor_id, action, window_start, hit_count, updated_at)
  values (p_actor_id, left(trim(p_action),80), v_window, 1, now())
  on conflict (actor_id, action, window_start)
  do update set
    hit_count = private.security_rate_limits.hit_count + 1,
    updated_at = now()
  returning hit_count into v_count;

  delete from private.security_rate_limits
  where window_start < now() - interval '2 days';

  return v_count <= p_limit;
end;
$$;

revoke all on function public.security_rate_limit_consume(uuid,text,integer,integer) from public, anon, authenticated;
grant execute on function public.security_rate_limit_consume(uuid,text,integer,integer) to service_role;
