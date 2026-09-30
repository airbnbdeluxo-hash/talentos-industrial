-- Candidate responses are owned, audited, and do not reopen terminal decisions.
create or replace function private.respond_to_interview_impl(p_interview_id uuid,p_status text)
returns public.interviews language plpgsql security definer set search_path='' as $$
declare r public.interviews;
begin
 if auth.uid() is null then raise exception 'authentication required'; end if;
 if p_status is null or p_status not in ('confirmada','cancelada') then raise exception 'invalid interview status'; end if;
 select i.* into r from public.interviews i join public.applications a on a.id=i.application_id
 where i.id=p_interview_id and a.candidate_id=auth.uid() for update of i;
 if not found then raise exception 'not authorized for this interview'; end if;
 if r.status=p_status then return r; end if;
 if r.status not in ('agendada','confirmada') then raise exception 'Esta entrevista já foi encerrada'; end if;
 if p_status='confirmada' and r.scheduled_at<=now() then raise exception 'Não é possível confirmar uma entrevista passada'; end if;
 update public.interviews set status=p_status,updated_at=now() where id=r.id returning * into r;
 insert into public.audit_events(actor_id,action,entity_type,entity_id,metadata)
 values(auth.uid(),'interview_response','interviews',r.id,jsonb_build_object('status',p_status));
 return r;
end $$;
create or replace function private.respond_to_offer_impl(p_offer_id uuid,p_status text)
returns public.offers language plpgsql security definer set search_path='' as $$
declare r public.offers; v_app public.applications;
begin
 if auth.uid() is null then raise exception 'authentication required'; end if;
 if p_status is null or p_status not in ('aceita','recusada') then raise exception 'invalid offer status'; end if;
 select o.* into r from public.offers o join public.applications a on a.id=o.application_id
 where o.id=p_offer_id and a.candidate_id=auth.uid() for update of o;
 if not found then raise exception 'not authorized for this offer'; end if;
 if r.status=p_status then return r; end if;
 if r.status<>'enviada' then raise exception 'Esta proposta não está disponível para resposta'; end if;
 select * into v_app from public.applications where id=r.application_id for update;
 if v_app.status in ('rejeitado','contratado') then raise exception 'Este processo já foi encerrado'; end if;
 update public.offers set status=p_status,responded_at=now(),updated_at=now() where id=r.id returning * into r;
 if p_status='aceita' then update public.applications set status='contratado',updated_at=now() where id=r.application_id; end if;
 insert into public.audit_events(actor_id,action,entity_type,entity_id,metadata)
 values(auth.uid(),'offer_response','offers',r.id,jsonb_build_object('status',p_status));
 return r;
end $$;
revoke all on function private.respond_to_interview_impl(uuid,text),private.respond_to_offer_impl(uuid,text),private.get_application_contact_impl(uuid) from public,anon;
grant execute on function private.respond_to_interview_impl(uuid,text),private.respond_to_offer_impl(uuid,text),private.get_application_contact_impl(uuid) to authenticated;
