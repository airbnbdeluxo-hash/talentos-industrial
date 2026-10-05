-- Authenticated-only application RPCs.
revoke execute on function public.attach_training_resources(uuid) from public, anon;
grant execute on function public.attach_training_resources(uuid) to authenticated;

revoke execute on function public.calculate_readiness(uuid, uuid) from public, anon;
grant execute on function public.calculate_readiness(uuid, uuid) to authenticated;

revoke execute on function public.get_training_plan_resources(uuid) from public, anon;
grant execute on function public.get_training_plan_resources(uuid) to authenticated;

revoke execute on function public.reschedule_interview(uuid, timestamptz, integer, text, text, text) from public, anon;
grant execute on function public.reschedule_interview(uuid, timestamptz, integer, text, text, text) to authenticated;

revoke execute on function public.update_job_alert(uuid, boolean) from public, anon;
grant execute on function public.update_job_alert(uuid, boolean) to authenticated;

-- Trigger helpers are never valid direct client RPCs.
revoke execute on function public.enforce_evidence_validation_state() from public, anon, authenticated;
revoke execute on function public.guard_employment_outcome_skill_write() from public, anon, authenticated;
revoke execute on function public.guard_employment_outcome_write() from public, anon, authenticated;
revoke execute on function public.guard_training_recommendation_insert() from public, anon, authenticated;
revoke execute on function public.guard_training_recommendation_update() from public, anon, authenticated;
revoke execute on function public.prevent_profile_role_change() from public, anon, authenticated;
revoke execute on function public.protect_candidate_skill_verification() from public, anon, authenticated;
