create table if not exists public.privacy_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  request_type text not null default 'account_deletion'
    check (request_type in ('account_deletion')),
  status text not null default 'pending'
    check (status in ('pending','in_review','completed','rejected','cancelled')),
  requested_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  resolved_at timestamptz,
  admin_note text
);

alter table public.privacy_requests enable row level security;

create unique index if not exists privacy_requests_one_active_deletion_idx
  on public.privacy_requests(user_id, request_type)
  where request_type = 'account_deletion'
    and status in ('pending','in_review');

create index if not exists privacy_requests_status_requested_idx
  on public.privacy_requests(status, requested_at desc);

revoke all on table public.privacy_requests from public, anon, authenticated;
grant select, insert, update on table public.privacy_requests to authenticated;

drop policy if exists privacy_requests_access on public.privacy_requests;
create policy privacy_requests_access
  on public.privacy_requests
  for select
  to authenticated
  using (user_id = (select auth.uid()) or private.is_admin());

drop policy if exists privacy_requests_insert on public.privacy_requests;
create policy privacy_requests_insert
  on public.privacy_requests
  for insert
  to authenticated
  with check (
    private.is_admin()
    or (
      user_id = (select auth.uid())
      and request_type = 'account_deletion'
      and status = 'pending'
    )
  );

drop policy if exists privacy_requests_admin_update on public.privacy_requests;
create policy privacy_requests_admin_update
  on public.privacy_requests
  for update
  to authenticated
  using (private.is_admin())
  with check (private.is_admin());

create or replace function public.request_my_account_deletion()
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_row public.privacy_requests;
begin
  if v_user is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select *
  into v_row
  from public.privacy_requests
  where user_id = v_user
    and request_type = 'account_deletion'
    and status in ('pending','in_review')
  order by requested_at desc
  limit 1;

  if found then
    return to_jsonb(v_row);
  end if;

  insert into public.privacy_requests(user_id, request_type, status)
  values (v_user, 'account_deletion', 'pending')
  returning * into v_row;

  return to_jsonb(v_row);
end;
$$;

revoke all on function public.request_my_account_deletion() from public, anon;
grant execute on function public.request_my_account_deletion() to authenticated;

create or replace function private.export_candidate_data(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller uuid := auth.uid();
  v_result jsonb;
begin
  if v_caller is null or v_caller <> p_user_id then
    raise exception 'Not authorized' using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = p_user_id
      and p.role::text = 'candidato'
  ) then
    raise exception 'Candidate account required' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'generated_at', now(),
    'user_id', p_user_id,
    'profile', (
      select to_jsonb(p)
      from public.profiles p
      where p.id = p_user_id
    ),
    'candidate_profile', (
      select to_jsonb(cp)
      from public.candidate_profiles cp
      where cp.profile_id = p_user_id
    ),
    'skills', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'skill_id', cs.skill_id,
          'skill_name', s.name,
          'proficiency', cs.proficiency,
          'verified', cs.verified,
          'years_experience', cs.years_experience,
          'source_type', cs.source_type,
          'source_confidence', cs.source_confidence,
          'source_excerpt', cs.source_excerpt,
          'source_resume_id', cs.source_resume_id
        )
        order by s.name
      )
      from public.candidate_skills cs
      join public.skills s on s.id = cs.skill_id
      where cs.candidate_id = p_user_id
    ), '[]'::jsonb),
    'evidence', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', se.id,
          'skill_id', se.skill_id,
          'skill_name', s.name,
          'evidence_type', se.evidence_type,
          'title', se.title,
          'issuer', se.issuer,
          'verified', se.verified,
          'verified_at', se.verified_at,
          'expires_at', se.expires_at,
          'score', se.score,
          'notes', se.notes,
          'file_name', se.file_name,
          'mime_type', se.mime_type,
          'file_size', se.file_size,
          'validation_status', se.validation_status,
          'reviewed_at', se.reviewed_at,
          'review_note', se.review_note,
          'integrity_status', se.integrity_status,
          'created_at', se.created_at
        )
        order by se.created_at
      )
      from public.skill_evidence se
      left join public.skills s on s.id = se.skill_id
      where se.candidate_id = p_user_id
    ), '[]'::jsonb),
    'preferences', (
      select to_jsonb(tp)
      from public.talent_preferences tp
      where tp.candidate_id = p_user_id
    ),
    'resume_metadata', (
      select jsonb_build_object(
        'id', cr.id,
        'file_name', cr.file_name,
        'mime_type', cr.mime_type,
        'file_size', cr.file_size,
        'created_at', cr.created_at,
        'updated_at', cr.updated_at
      )
      from public.candidate_resumes cr
      where cr.candidate_id = p_user_id
    ),
    'applications', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'application', to_jsonb(a),
          'job', jsonb_build_object(
            'id', j.id,
            'title', j.title,
            'city', j.city,
            'status', j.status,
            'company_name', coalesce(j.company_public_name, c.name)
          )
        )
        order by a.created_at
      )
      from public.applications a
      join public.jobs j on j.id = a.job_id
      left join public.companies c on c.id = j.company_id
      where a.candidate_id = p_user_id
    ), '[]'::jsonb),
    'application_events', coalesce((
      select jsonb_agg(to_jsonb(ev) order by ev.created_at)
      from public.application_events ev
      join public.applications a on a.id = ev.application_id
      where a.candidate_id = p_user_id
    ), '[]'::jsonb),
    'saved_jobs', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'saved_at', sj.created_at,
          'job_id', j.id,
          'title', j.title,
          'city', j.city,
          'status', j.status
        )
        order by sj.created_at
      )
      from public.saved_jobs sj
      join public.jobs j on j.id = sj.job_id
      where sj.candidate_id = p_user_id
    ), '[]'::jsonb),
    'job_alerts', coalesce((
      select jsonb_agg(to_jsonb(ja) order by ja.created_at)
      from public.job_alerts ja
      where ja.candidate_id = p_user_id
    ), '[]'::jsonb),
    'messages', coalesce((
      select jsonb_agg(to_jsonb(m) order by m.created_at)
      from public.messages m
      join public.applications a on a.id = m.application_id
      where a.candidate_id = p_user_id
    ), '[]'::jsonb),
    'interviews', coalesce((
      select jsonb_agg(to_jsonb(i) order by i.scheduled_at)
      from public.interviews i
      join public.applications a on a.id = i.application_id
      where a.candidate_id = p_user_id
    ), '[]'::jsonb),
    'offers', coalesce((
      select jsonb_agg(to_jsonb(o) order by o.created_at)
      from public.offers o
      join public.applications a on a.id = o.application_id
      where a.candidate_id = p_user_id
    ), '[]'::jsonb),
    'notifications', coalesce((
      select jsonb_agg(to_jsonb(n) order by n.created_at)
      from public.notifications n
      where n.user_id = p_user_id
    ), '[]'::jsonb),
    'availability', coalesce((
      select jsonb_agg(to_jsonb(ca) order by ca.weekday, ca.start_time)
      from public.candidate_availability ca
      where ca.candidate_id = p_user_id
    ), '[]'::jsonb),
    'training_recommendations', coalesce((
      select jsonb_agg(to_jsonb(tr) order by tr.created_at)
      from public.training_recommendations tr
      where tr.candidate_id = p_user_id
    ), '[]'::jsonb),
    'challenge_attempts', coalesce((
      select jsonb_agg(to_jsonb(ch) order by ch.started_at)
      from public.challenge_attempts ch
      where ch.candidate_id = p_user_id
    ), '[]'::jsonb),
    'skill_assessments', coalesce((
      select jsonb_agg(to_jsonb(sa) order by sa.created_at)
      from public.skill_assessments sa
      where sa.candidate_id = p_user_id
    ), '[]'::jsonb),
    'skill_progress_events', coalesce((
      select jsonb_agg(to_jsonb(cse) order by cse.created_at)
      from public.candidate_skill_events cse
      where cse.candidate_id = p_user_id
    ), '[]'::jsonb),
    'outcome_skill_progress_events', coalesce((
      select jsonb_agg(to_jsonb(csoe) order by csoe.created_at)
      from public.candidate_skill_outcome_events csoe
      where csoe.candidate_id = p_user_id
    ), '[]'::jsonb),
    'employment_outcomes', coalesce((
      select jsonb_agg(to_jsonb(eo) order by eo.created_at)
      from public.employment_outcomes eo
      where eo.candidate_id = p_user_id
    ), '[]'::jsonb),
    'employment_outcome_skill_signals', coalesce((
      select jsonb_agg(to_jsonb(eos) order by eos.created_at)
      from public.employment_outcome_skill_signals eos
      join public.employment_outcomes eo on eo.id = eos.outcome_id
      where eo.candidate_id = p_user_id
    ), '[]'::jsonb),
    'privacy_requests', coalesce((
      select jsonb_agg(to_jsonb(pr) order by pr.requested_at)
      from public.privacy_requests pr
      where pr.user_id = p_user_id
    ), '[]'::jsonb)
  )
  into v_result;

  return v_result;
end;
$$;

revoke all on function private.export_candidate_data(uuid) from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.export_candidate_data(uuid) to authenticated;

create or replace function public.export_my_candidate_data()
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select private.export_candidate_data((select auth.uid()));
$$;

revoke all on function public.export_my_candidate_data() from public, anon;
grant execute on function public.export_my_candidate_data() to authenticated;
