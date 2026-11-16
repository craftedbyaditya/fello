-- Harden trigger-only SECURITY DEFINER RPCs + Board FK indexes + search_path.
-- Does not change plan limit values or function signatures.

-- Trigger / internal helpers must not be callable via PostgREST.
revoke all on function public.enqueue_feedback_ai_job() from public, anon, authenticated;
revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function public.enforce_form_plan_limit() from public, anon, authenticated;
revoke all on function public.enforce_response_plan_limit() from public, anon, authenticated;
-- This helper existed in an earlier local schema but is not part of the
-- migration history. It has no callers; revoke it only when upgrading a
-- database that still contains it. A clean database must not fail here.
do $$
begin
  if to_regprocedure('public.rls_auto_enable()') is not null then
    revoke all on function public.rls_auto_enable() from public, anon, authenticated;
  end if;
end;
$$;
revoke all on function public.enforce_logo_plan_gate() from public, anon, authenticated;

-- Re-assert service_role-only claim after Board migration replaced the function body.
revoke all on function public.claim_feedback_ai_jobs(integer) from public, anon, authenticated;
grant execute on function public.claim_feedback_ai_jobs(integer) to service_role;

-- Helpers that leak org counts / session should not be anon-callable.
revoke all on function public.org_survey_count(uuid) from public, anon;
grant execute on function public.org_survey_count(uuid) to authenticated, service_role;

revoke all on function public.org_response_count_this_month(uuid) from public, anon;
grant execute on function public.org_response_count_this_month(uuid) to authenticated, service_role;

revoke all on function public.current_org_id() from public, anon;
grant execute on function public.current_org_id() to authenticated, service_role;

revoke all on function public.current_user_role() from public, anon;
grant execute on function public.current_user_role() to authenticated, service_role;

revoke all on function public.is_org_admin() from public, anon;
grant execute on function public.is_org_admin() to authenticated, service_role;

-- Fix mutable search_path without changing function bodies/signatures.
alter function public.plan_max_surveys(text) set search_path = public;
alter function public.plan_max_responses(text) set search_path = public;
alter function public.month_period_start(timestamptz) set search_path = public;
alter function public.enforce_logo_plan_gate() set search_path = public;

-- Board / AI FK covering indexes
create index if not exists complaint_tasks_analysis_id_idx
  on public.complaint_tasks (analysis_id)
  where analysis_id is not null;

create index if not exists complaint_tasks_created_by_idx
  on public.complaint_tasks (created_by)
  where created_by is not null;

create index if not exists task_comments_org_id_idx
  on public.task_comments (org_id);

create index if not exists task_comments_author_id_idx
  on public.task_comments (author_id);

create index if not exists notification_events_org_id_idx
  on public.notification_events (org_id);

-- RLS initplan: wrap auth.uid() in (select ...) for Board policies
drop policy if exists complaint_tasks_insert_member on public.complaint_tasks;
create policy complaint_tasks_insert_member on public.complaint_tasks
  for insert with check (
    org_id = public.current_org_id()
    and source = 'manual'
    and created_by = (select auth.uid())
    and response_id is null
    and status = 'open'
  );

drop policy if exists task_comments_insert_member on public.task_comments;
create policy task_comments_insert_member on public.task_comments
  for insert with check (
    org_id = public.current_org_id()
    and author_id = (select auth.uid())
    and exists (
      select 1 from public.complaint_tasks t
      where t.id = task_id and t.org_id = public.current_org_id()
    )
  );

drop policy if exists notification_events_select_own on public.notification_events;
create policy notification_events_select_own on public.notification_events
  for select using (
    user_id = (select auth.uid()) and org_id = public.current_org_id()
  );

drop policy if exists notification_events_update_own on public.notification_events;
create policy notification_events_update_own on public.notification_events
  for update using (
    user_id = (select auth.uid()) and org_id = public.current_org_id()
  )
  with check (
    user_id = (select auth.uid()) and org_id = public.current_org_id()
  );
