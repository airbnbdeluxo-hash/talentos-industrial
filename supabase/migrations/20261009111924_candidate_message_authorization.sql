-- Candidate messages must not depend on reading another user's membership row.
-- Keep company_members private; return only an authorization boolean, scoped to
-- the authenticated sender and the exact application/recipient pair.
create or replace function private.can_send_application_message(
  p_application_id uuid, p_sender_id uuid, p_recipient_id uuid
) returns boolean
language sql stable security definer set search_path = ''
as $$
  select auth.uid() is not null
    and p_sender_id = auth.uid()
    and exists (
      select 1 from public.applications a
      join public.jobs j on j.id = a.job_id
      where a.id = p_application_id
        and (
          (a.candidate_id = auth.uid() and exists (
            select 1 from public.company_members cm
            where cm.company_id = j.company_id
              and cm.user_id = p_recipient_id
              and cm.member_role in ('owner','recruiter','viewer')
          ))
          or (p_recipient_id = a.candidate_id and exists (
            select 1 from public.company_members cm
            where cm.company_id = j.company_id
              and cm.user_id = auth.uid()
              and cm.member_role in ('owner','recruiter')
          ))
        )
    );
$$;
revoke all on function private.can_send_application_message(uuid,uuid,uuid) from public, anon;
grant execute on function private.can_send_application_message(uuid,uuid,uuid) to authenticated;

drop policy messages_insert on public.messages;
create policy messages_insert on public.messages for insert to authenticated
with check (
  sender_id = (select auth.uid())
  and private.can_send_application_message(application_id,sender_id,recipient_id)
);
