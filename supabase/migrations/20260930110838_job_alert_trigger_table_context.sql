create or replace function public.trg_notify_matching_job_alerts()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_table_schema<>'public' then raise exception 'invalid trigger schema'; end if;
 if tg_table_name='jobs' then
   perform public.notify_matching_job_alerts_for_job(new.id);
 elsif tg_table_name='job_skills' then
   perform public.notify_matching_job_alerts_for_job(new.job_id);
 else raise exception 'invalid trigger table'; end if;
 return new;
end $$;
revoke all on function public.trg_notify_matching_job_alerts() from public,anon,authenticated;
