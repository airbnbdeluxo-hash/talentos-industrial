-- Bind talent pool access to the pool's own company.
-- Previous policies compared cm.company_id to itself, which made the company
-- predicate tautological and could allow cross-company access.

drop policy if exists talent_pools_select on public.talent_pools;
drop policy if exists talent_pools_insert on public.talent_pools;
drop policy if exists talent_pools_update on public.talent_pools;
drop policy if exists talent_pools_delete on public.talent_pools;

create policy talent_pools_select
on public.talent_pools
for select
to authenticated
using (
  private.is_admin()
  or exists (
    select 1
    from public.company_members cm
    where cm.company_id = talent_pools.company_id
      and cm.user_id = (select auth.uid())
  )
);

create policy talent_pools_insert
on public.talent_pools
for insert
to authenticated
with check (
  private.is_admin()
  or (
    created_by = (select auth.uid())
    and exists (
      select 1
      from public.company_members cm
      where cm.company_id = talent_pools.company_id
        and cm.user_id = (select auth.uid())
        and cm.member_role in ('owner','recruiter')
    )
  )
);

create policy talent_pools_update
on public.talent_pools
for update
to authenticated
using (
  private.is_admin()
  or exists (
    select 1
    from public.company_members cm
    where cm.company_id = talent_pools.company_id
      and cm.user_id = (select auth.uid())
      and cm.member_role in ('owner','recruiter')
  )
)
with check (
  private.is_admin()
  or exists (
    select 1
    from public.company_members cm
    where cm.company_id = talent_pools.company_id
      and cm.user_id = (select auth.uid())
      and cm.member_role in ('owner','recruiter')
  )
);

create policy talent_pools_delete
on public.talent_pools
for delete
to authenticated
using (
  private.is_admin()
  or exists (
    select 1
    from public.company_members cm
    where cm.company_id = talent_pools.company_id
      and cm.user_id = (select auth.uid())
      and cm.member_role in ('owner','recruiter')
  )
);
