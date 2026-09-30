-- One transaction saves the profile, resume metadata, preferences and declared skills.
-- An invalid row rolls the entire save back. Reviewed skills are preserved.
create or replace function public.save_candidate_passport(p_profile jsonb,p_skills jsonb,p_resume jsonb default null)
returns uuid language plpgsql security invoker set search_path='' as $$
declare v_user uuid:=auth.uid(); v_resume uuid; v_row jsonb; v_existing public.candidate_skills;
 v_name text:=nullif(trim(p_profile->>'name'),''); v_city text:=nullif(trim(p_profile->>'city'),'');
begin
 if v_user is null or private.current_role() is distinct from 'candidato' then raise exception 'Somente candidatos podem salvar o próprio currículo'; end if;
 if v_name is null or v_city is null or nullif(trim(p_profile->>'role'),'') is null then raise exception 'Informe nome, função e cidade'; end if;
 if p_skills is null or jsonb_typeof(p_skills)<>'array' then raise exception 'Lista de habilidades inválida'; end if;
 if jsonb_array_length(p_skills)>150 then raise exception 'Limite de 150 habilidades'; end if;
 perform 1 from public.profiles where id=v_user for update;
 insert into public.candidate_profiles(profile_id,display_name,role_title,city,years_experience,desired_salary,bio,searchable,visibility_consent_at,consent_version)
 values(v_user,v_name,trim(p_profile->>'role'),v_city,greatest(0,coalesce((p_profile->>'years')::numeric,0)),
 greatest(0,coalesce((p_profile->>'salary')::numeric,0)),nullif(trim(p_profile->>'bio'),''),coalesce((p_profile->>'searchable')::boolean,false),
 case when coalesce((p_profile->>'searchable')::boolean,false) then now() end,
 case when coalesce((p_profile->>'searchable')::boolean,false) then 'v1' end)
 on conflict(profile_id) do update set display_name=excluded.display_name,role_title=excluded.role_title,city=excluded.city,
 years_experience=excluded.years_experience,desired_salary=excluded.desired_salary,bio=excluded.bio,
 searchable=excluded.searchable,visibility_consent_at=excluded.visibility_consent_at,consent_version=excluded.consent_version,updated_at=now();
 if p_resume is not null then
   if p_resume->>'mime_type' not in ('application/pdf','application/vnd.openxmlformats-officedocument.wordprocessingml.document')
    or coalesce((p_resume->>'file_size')::bigint,0) not between 1 and 10485760
    or split_part(p_resume->>'storage_path','/',1) is distinct from v_user::text
    or not exists(select 1 from storage.objects o where o.bucket_id='candidate-resumes' and o.name=p_resume->>'storage_path')
   then raise exception 'Arquivo de currículo inválido ou não pertence ao candidato'; end if;
   insert into public.candidate_resumes(candidate_id,storage_path,file_name,mime_type,file_size)
   values(v_user,p_resume->>'storage_path',p_resume->>'file_name',p_resume->>'mime_type',(p_resume->>'file_size')::bigint)
   on conflict(candidate_id) do update set storage_path=excluded.storage_path,file_name=excluded.file_name,mime_type=excluded.mime_type,file_size=excluded.file_size,updated_at=now()
   returning id into v_resume;
 end if;
 if p_profile ? 'preferredShifts' then
   insert into public.talent_preferences(candidate_id,preferred_shifts)
   values(v_user,array(select jsonb_array_elements_text(p_profile->'preferredShifts')))
   on conflict(candidate_id) do update set preferred_shifts=excluded.preferred_shifts;
 end if;
 for v_row in select value from jsonb_array_elements(p_skills) loop
   if v_row->>'source_type' is null or v_row->>'source_type' not in ('manual','curriculo') then raise exception 'Origem de habilidade inválida'; end if;
   if v_row->>'source_type'='curriculo' and v_resume is null then raise exception 'Currículo não enviado'; end if;
   select * into v_existing from public.candidate_skills where candidate_id=v_user and skill_id=(v_row->>'skill_id')::uuid;
   if found then
     -- Editing the resume never downgrades established proficiency, provenance or verification.
     update public.candidate_skills set years_experience=greatest(years_experience,coalesce((v_row->>'years_experience')::numeric,0))
     where candidate_id=v_user and skill_id=(v_row->>'skill_id')::uuid;
   else
     insert into public.candidate_skills(candidate_id,skill_id,proficiency,verified,years_experience,source_type,source_confidence,source_excerpt,source_resume_id)
     values(v_user,(v_row->>'skill_id')::uuid,case when v_row->>'source_type'='curriculo' then 1 else 3 end,false,
     greatest(0,coalesce((v_row->>'years_experience')::numeric,0)),v_row->>'source_type',
     case when v_row->>'source_type'='curriculo' then least(1,greatest(0,coalesce((v_row->>'source_confidence')::numeric,0.6))) end,
     case when v_row->>'source_type'='curriculo' then left(v_row->>'source_excerpt',500) end,
     case when v_row->>'source_type'='curriculo' then v_resume end);
   end if;
 end loop;
 delete from public.candidate_skills cs where cs.candidate_id=v_user and not cs.verified and cs.source_type in ('manual','curriculo')
 and not exists(select 1 from jsonb_array_elements(p_skills) row where (row->>'skill_id')::uuid=cs.skill_id);
 perform public.log_audit_event('candidate_passport_saved','candidate_profiles',v_user,jsonb_build_object('skills_count',jsonb_array_length(p_skills),'resume_changed',p_resume is not null));
 return v_resume;
end $$;
revoke all on function public.save_candidate_passport(jsonb,jsonb,jsonb) from public,anon;
grant execute on function public.save_candidate_passport(jsonb,jsonb,jsonb) to authenticated;
