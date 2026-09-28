-- TalentOS: consolidate training UPDATE RLS into one permissive policy
drop policy if exists candidate_training_update on public.training_recommendations;
drop policy if exists training_generation_update on public.training_recommendations;

create policy training_update on public.training_recommendations
for update to authenticated
using(
  candidate_id=(select auth.uid())
  or exists(
    select 1
    from public.jobs j
    join public.company_members cm on cm.company_id=j.company_id
    where j.id=training_recommendations.job_id
      and cm.user_id=(select auth.uid())
      and cm.member_role in ('owner','recruiter')
  )
)
with check(
  candidate_id=(select auth.uid())
  or exists(
    select 1
    from public.jobs j
    join public.company_members cm on cm.company_id=j.company_id
    where j.id=training_recommendations.job_id
      and cm.user_id=(select auth.uid())
      and cm.member_role in ('owner','recruiter')
  )
);