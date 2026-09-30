alter table public.applications
  add column if not exists rejection_reason_code text,
  add column if not exists rejection_reason_note text;

alter table public.applications
  drop constraint if exists applications_rejection_reason_code_check;

alter table public.applications
  add constraint applications_rejection_reason_code_check
  check (
    rejection_reason_code is null
    or rejection_reason_code = any(array[
      'habilidades'::text,
      'experiencia'::text,
      'disponibilidade'::text,
      'pretensao_salarial'::text,
      'localizacao'::text,
      'entrevista'::text,
      'vaga_encerrada'::text,
      'outro'::text
    ])
  );

alter table public.applications
  drop constraint if exists applications_rejection_reason_note_length_check;

alter table public.applications
  add constraint applications_rejection_reason_note_length_check
  check (rejection_reason_note is null or char_length(rejection_reason_note) <= 1000);

comment on column public.applications.rejection_reason_code is
  'Structured recruiting reason for the current rejected state. Historical reasons remain in application_events.';
comment on column public.applications.rejection_reason_note is
  'Optional recruiter note for the current rejected state, max 1000 chars.';

create or replace function public.log_application_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_note text;
begin
  v_note := nullif(pg_catalog.current_setting('talentos.application_event_note', true), '');

  if tg_op='INSERT' then
    insert into public.application_events(application_id,actor_id,from_status,to_status,note)
    values(new.id,(select auth.uid()),null,new.status,coalesce(v_note,'Candidatura criada'));
  elsif new.status is distinct from old.status then
    insert into public.application_events(application_id,actor_id,from_status,to_status,note)
    values(new.id,(select auth.uid()),old.status,new.status,v_note);
  end if;
  return new;
end;
$function$;

drop function if exists public.update_application_status(uuid,text);

create function public.update_application_status(
  p_application_id uuid,
  p_status text,
  p_rejection_reason text default null,
  p_rejection_note text default null
)
returns public.applications
language plpgsql
security invoker
set search_path = ''
as $function$
declare
  result_row public.applications;
  v_event_note text;
  v_reason_label text;
begin
  if (select auth.uid()) is null then
    raise exception 'authentication required';
  end if;

  if p_status not in ('novo','triagem','entrevista','aprovado','rejeitado','contratado') then
    raise exception 'invalid application status';
  end if;

  if p_rejection_note is not null and char_length(p_rejection_note) > 1000 then
    raise exception 'rejection note too long';
  end if;

  if p_status='rejeitado' then
    if p_rejection_reason is null or p_rejection_reason not in (
      'habilidades','experiencia','disponibilidade','pretensao_salarial',
      'localizacao','entrevista','vaga_encerrada','outro'
    ) then
      raise exception 'rejection reason required';
    end if;

    v_reason_label := case p_rejection_reason
      when 'habilidades' then 'Habilidades não atendem aos requisitos atuais'
      when 'experiencia' then 'Experiência não atende ao momento da vaga'
      when 'disponibilidade' then 'Disponibilidade incompatível'
      when 'pretensao_salarial' then 'Pretensão salarial incompatível'
      when 'localizacao' then 'Localização ou deslocamento incompatível'
      when 'entrevista' then 'Avaliação da entrevista'
      when 'vaga_encerrada' then 'Vaga encerrada ou necessidade alterada'
      else 'Outro motivo'
    end;

    v_event_note := 'Motivo da rejeição: ' || v_reason_label
      || case when nullif(btrim(coalesce(p_rejection_note,'')),'') is not null
              then ' · ' || left(btrim(p_rejection_note),1000)
              else '' end;
  else
    v_event_note := null;
  end if;

  perform pg_catalog.set_config('talentos.application_event_note',coalesce(v_event_note,''),true);

  update public.applications a
  set status=p_status,
      rejection_reason_code=case when p_status='rejeitado' then p_rejection_reason else null end,
      rejection_reason_note=case when p_status='rejeitado' then nullif(btrim(p_rejection_note),'') else null end,
      updated_at=now()
  where a.id=p_application_id
    and (
      private.is_admin()
      or exists(
        select 1
        from public.jobs j
        join public.company_members cm on cm.company_id=j.company_id
        where j.id=a.job_id
          and cm.user_id=(select auth.uid())
          and cm.member_role in ('owner','recruiter')
      )
    )
  returning a.* into result_row;

  if result_row.id is null then
    raise exception 'not authorized for this application';
  end if;

  return result_row;
end;
$function$;

revoke execute on function public.update_application_status(uuid,text,text,text) from public, anon;
grant execute on function public.update_application_status(uuid,text,text,text) to authenticated;
