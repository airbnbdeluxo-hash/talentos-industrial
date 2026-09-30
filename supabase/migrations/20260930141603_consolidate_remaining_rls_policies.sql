-- Final RLS policy consolidation for remaining multiple-permissive warnings.

-- application_events
drop policy if exists admin_full_access_application_events on public.application_events;
alter policy application_events_access on public.application_events
  using (
    private.is_admin()
    or exists (
      select 1
      from public.applications a
      where a.id = application_events.application_id
        and (
          a.candidate_id = (select auth.uid())
          or exists (
            select 1
            from public.jobs j
            join public.company_members cm on cm.company_id = j.company_id
            where j.id = a.job_id
              and cm.user_id = (select auth.uid())
          )
        )
    )
  );
drop policy if exists application_events_admin_insert on public.application_events;
create policy application_events_admin_insert on public.application_events
  for insert to authenticated
  with check (private.is_admin());
drop policy if exists application_events_admin_update on public.application_events;
create policy application_events_admin_update on public.application_events
  for update to authenticated
  using (private.is_admin())
  with check (private.is_admin());
drop policy if exists application_events_admin_delete on public.application_events;
create policy application_events_admin_delete on public.application_events
  for delete to authenticated
  using (private.is_admin());

-- capability_nodes
drop policy if exists admin_full_access_capability_nodes on public.capability_nodes;
alter policy capability_nodes_read on public.capability_nodes
  using (private.is_admin() or active = true);
drop policy if exists capability_nodes_admin_insert on public.capability_nodes;
create policy capability_nodes_admin_insert on public.capability_nodes
  for insert to authenticated
  with check (private.is_admin());
drop policy if exists capability_nodes_admin_update on public.capability_nodes;
create policy capability_nodes_admin_update on public.capability_nodes
  for update to authenticated
  using (private.is_admin())
  with check (private.is_admin());
drop policy if exists capability_nodes_admin_delete on public.capability_nodes;
create policy capability_nodes_admin_delete on public.capability_nodes
  for delete to authenticated
  using (private.is_admin());

-- capability_edges
drop policy if exists admin_full_access_capability_edges on public.capability_edges;
alter policy capability_edges_read on public.capability_edges
  using (
    private.is_admin()
    or (
      exists (
        select 1 from public.capability_nodes n
        where n.id = capability_edges.from_node_id and n.active
      )
      and exists (
        select 1 from public.capability_nodes n
        where n.id = capability_edges.to_node_id and n.active
      )
    )
  );
drop policy if exists capability_edges_admin_insert on public.capability_edges;
create policy capability_edges_admin_insert on public.capability_edges
  for insert to authenticated
  with check (private.is_admin());
drop policy if exists capability_edges_admin_update on public.capability_edges;
create policy capability_edges_admin_update on public.capability_edges
  for update to authenticated
  using (private.is_admin())
  with check (private.is_admin());
drop policy if exists capability_edges_admin_delete on public.capability_edges;
create policy capability_edges_admin_delete on public.capability_edges
  for delete to authenticated
  using (private.is_admin());

-- challenge_attempts
drop policy if exists admin_full_access_challenge_attempts on public.challenge_attempts;
alter policy challenge_attempts_self_insert on public.challenge_attempts
  with check (private.is_admin() or candidate_id = (select auth.uid()));
alter policy challenge_attempts_self_select on public.challenge_attempts
  using (private.is_admin() or candidate_id = (select auth.uid()));
alter policy challenge_attempts_self_update on public.challenge_attempts
  using (private.is_admin() or candidate_id = (select auth.uid()))
  with check (private.is_admin() or candidate_id = (select auth.uid()));
drop policy if exists challenge_attempts_admin_delete on public.challenge_attempts;
create policy challenge_attempts_admin_delete on public.challenge_attempts
  for delete to authenticated
  using (private.is_admin());

-- challenge_library
drop policy if exists admin_full_access_challenge_library on public.challenge_library;
alter policy challenge_library_read on public.challenge_library
  using (private.is_admin() or active = true);
drop policy if exists challenge_library_admin_insert on public.challenge_library;
create policy challenge_library_admin_insert on public.challenge_library
  for insert to authenticated
  with check (private.is_admin());
drop policy if exists challenge_library_admin_update on public.challenge_library;
create policy challenge_library_admin_update on public.challenge_library
  for update to authenticated
  using (private.is_admin())
  with check (private.is_admin());
drop policy if exists challenge_library_admin_delete on public.challenge_library;
create policy challenge_library_admin_delete on public.challenge_library
  for delete to authenticated
  using (private.is_admin());

-- skills
drop policy if exists admin_full_access_skills on public.skills;
drop policy if exists skills_admin_insert on public.skills;
create policy skills_admin_insert on public.skills
  for insert to authenticated
  with check (private.is_admin());
drop policy if exists skills_admin_update on public.skills;
create policy skills_admin_update on public.skills
  for update to authenticated
  using (private.is_admin())
  with check (private.is_admin());
drop policy if exists skills_admin_delete on public.skills;
create policy skills_admin_delete on public.skills
  for delete to authenticated
  using (private.is_admin());

-- talent_preferences
drop policy if exists admin_full_access_talent_preferences on public.talent_preferences;
alter policy preference_self on public.talent_preferences
  using (private.is_admin() or candidate_id = (select auth.uid()))
  with check (private.is_admin() or candidate_id = (select auth.uid()));

-- training_plan_resources
drop policy if exists training_plan_resources_candidate_select on public.training_plan_resources;
drop policy if exists training_plan_resources_company_select on public.training_plan_resources;
create policy training_plan_resources_access on public.training_plan_resources
  for select to authenticated
  using (
    exists (
      select 1
      from public.training_recommendations tr
      where tr.id = training_plan_resources.recommendation_id
        and tr.candidate_id = (select auth.uid())
    )
    or exists (
      select 1
      from public.training_recommendations tr
      join public.jobs j on j.id = tr.job_id
      join public.company_members cm on cm.company_id = j.company_id
      where tr.id = training_plan_resources.recommendation_id
        and cm.user_id = (select auth.uid())
    )
  );
