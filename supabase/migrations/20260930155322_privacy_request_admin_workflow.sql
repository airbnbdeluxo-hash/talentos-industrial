
create or replace function private.update_privacy_request_status(
  p_request_id uuid,
  p_status text,
  p_admin_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_row public.privacy_requests%rowtype;
  v_from text;
begin
  if v_actor is null or not private.is_admin() then
    raise exception 'Admin access required' using errcode = '42501';
  end if;

  if p_status not in ('in_review','completed','rejected','cancelled') then
    raise exception 'Invalid privacy request status' using errcode = '22023';
  end if;

  select *
  into v_row
  from public.privacy_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'Privacy request not found' using errcode = 'P0002';
  end if;

  if v_row.status = p_status then
    return to_jsonb(v_row);
  end if;

  if v_row.status in ('completed','rejected','cancelled') then
    raise exception 'Privacy request is already resolved' using errcode = '22023';
  end if;

  if v_row.status = 'pending'
     and p_status not in ('in_review','rejected','cancelled') then
    raise exception 'Request must be reviewed before completion' using errcode = '22023';
  end if;

  if v_row.status = 'in_review'
     and p_status not in ('completed','rejected','cancelled') then
    raise exception 'Invalid transition from in_review' using errcode = '22023';
  end if;

  v_from := v_row.status;

  update public.privacy_requests
  set status = p_status,
      updated_at = now(),
      resolved_at = case when p_status in ('completed','rejected','cancelled') then now() else null end,
      admin_note = case
        when nullif(btrim(coalesce(p_admin_note,'')),'') is null then admin_note
        else btrim(p_admin_note)
      end
  where id = p_request_id
  returning * into v_row;

  insert into public.audit_events(actor_id, action, entity_type, entity_id, metadata)
  values (
    v_actor,
    'privacy_request_status_updated',
    'privacy_request',
    p_request_id,
    jsonb_build_object(
      'from_status', v_from,
      'to_status', v_row.status,
      'request_type', v_row.request_type,
      'request_user_id', v_row.user_id,
      'admin_note_present', nullif(btrim(coalesce(p_admin_note,'')),'') is not null
    )
  );

  return to_jsonb(v_row);
end;
$$;

revoke all on function private.update_privacy_request_status(uuid,text,text) from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.update_privacy_request_status(uuid,text,text) to authenticated;

create or replace function public.update_privacy_request_status(
  p_request_id uuid,
  p_status text,
  p_admin_note text default null
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select private.update_privacy_request_status(p_request_id, p_status, p_admin_note);
$$;

revoke all on function public.update_privacy_request_status(uuid,text,text) from public, anon;
grant execute on function public.update_privacy_request_status(uuid,text,text) to authenticated;

revoke update on table public.privacy_requests from authenticated;
