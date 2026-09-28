create index employment_outcomes_created_by_idx
  on public.employment_outcomes(created_by, created_at desc);
create index outcome_skill_signals_created_by_idx
  on public.employment_outcome_skill_signals(created_by, created_at desc);

drop policy if exists employment_outcomes_insert on public.employment_outcomes;
create policy employment_outcomes_insert on public.employment_outcomes
for insert to authenticated
with check (
  (select current_setting('talentos.outcome_write', true)) = '1'
  and exists (
    select 1 from public.company_members cm
    where cm.company_id=employment_outcomes.company_id
      and cm.user_id=(select auth.uid())
      and cm.member_role in ('owner','recruiter')
  )
);

drop policy if exists employment_outcomes_update on public.employment_outcomes;
create policy employment_outcomes_update on public.employment_outcomes
for update to authenticated
using (
  exists (
    select 1 from public.company_members cm
    where cm.company_id=employment_outcomes.company_id
      and cm.user_id=(select auth.uid())
      and cm.member_role in ('owner','recruiter')
  )
)
with check (
  (select current_setting('talentos.outcome_write', true)) = '1'
  and exists (
    select 1 from public.company_members cm
    where cm.company_id=employment_outcomes.company_id
      and cm.user_id=(select auth.uid())
      and cm.member_role in ('owner','recruiter')
  )
);

drop policy if exists outcome_skill_signals_write on public.employment_outcome_skill_signals;
create policy outcome_skill_signals_write on public.employment_outcome_skill_signals
for insert to authenticated
with check (
  (select current_setting('talentos.outcome_skill_write', true)) = '1'
  and exists (
    select 1 from public.employment_outcomes eo
    join public.company_members cm on cm.company_id=eo.company_id
    where eo.id=employment_outcome_skill_signals.outcome_id
      and cm.user_id=(select auth.uid())
      and cm.member_role in ('owner','recruiter')
  )
);

drop policy if exists outcome_skill_signals_update on public.employment_outcome_skill_signals;
create policy outcome_skill_signals_update on public.employment_outcome_skill_signals
for update to authenticated
using (
  exists (
    select 1 from public.employment_outcomes eo
    join public.company_members cm on cm.company_id=eo.company_id
    where eo.id=employment_outcome_skill_signals.outcome_id
      and cm.user_id=(select auth.uid())
      and cm.member_role in ('owner','recruiter')
  )
)
with check (
  (select current_setting('talentos.outcome_skill_write', true)) = '1'
  and exists (
    select 1 from public.employment_outcomes eo
    join public.company_members cm on cm.company_id=eo.company_id
    where eo.id=employment_outcome_skill_signals.outcome_id
      and cm.user_id=(select auth.uid())
      and cm.member_role in ('owner','recruiter')
  )
);
