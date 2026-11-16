-- AI Feedback-to-Action workflow (additive).
-- Enqueues analysis jobs after responses are saved; Edge Function writes
-- analysis / complaint tasks / notifications with service_role only.

-- ---------------------------------------------------------------------------
-- Org AI controls (global kill switch is Edge env AI_ENABLED)
-- ---------------------------------------------------------------------------
alter table public.organizations
  add column if not exists ai_feedback_enabled boolean not null default true;

alter table public.organizations
  add column if not exists ai_monthly_analysis_limit integer not null default 100;

-- ---------------------------------------------------------------------------
-- Processing jobs (durable queue)
-- ---------------------------------------------------------------------------
create table if not exists public.feedback_processing_jobs (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  response_id uuid not null references public.responses (id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'done', 'failed', 'skipped')),
  attempts integer not null default 0,
  max_attempts integer not null default 3,
  last_error text,
  skip_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  processed_at timestamptz,
  unique (response_id)
);

create index if not exists feedback_processing_jobs_status_idx
  on public.feedback_processing_jobs (status, created_at)
  where status in ('pending', 'failed');

create index if not exists feedback_processing_jobs_org_idx
  on public.feedback_processing_jobs (org_id);

alter table public.feedback_processing_jobs enable row level security;

drop policy if exists feedback_jobs_select_member on public.feedback_processing_jobs;
create policy feedback_jobs_select_member on public.feedback_processing_jobs
  for select using (org_id = public.current_org_id());

-- ---------------------------------------------------------------------------
-- AI analysis results
-- ---------------------------------------------------------------------------
create table if not exists public.feedback_analysis (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  response_id uuid not null references public.responses (id) on delete cascade,
  sentiment text not null
    check (sentiment in ('positive', 'neutral', 'mixed', 'negative')),
  primary_category text not null default 'General',
  categories text[] not null default '{}',
  positive_aspects text[] not null default '{}',
  urgency text not null default 'low'
    check (urgency in ('low', 'medium', 'high', 'critical')),
  summary text not null default '',
  action_recommended boolean not null default false,
  confidence numeric(4,3) not null default 0
    check (confidence >= 0 and confidence <= 1),
  model text,
  created_at timestamptz not null default now(),
  unique (response_id)
);

create index if not exists feedback_analysis_org_idx
  on public.feedback_analysis (org_id, created_at desc);
create index if not exists feedback_analysis_category_idx
  on public.feedback_analysis (org_id, primary_category);

alter table public.feedback_analysis enable row level security;

drop policy if exists feedback_analysis_select_member on public.feedback_analysis;
create policy feedback_analysis_select_member on public.feedback_analysis
  for select using (org_id = public.current_org_id());

-- ---------------------------------------------------------------------------
-- Complaint tasks
-- ---------------------------------------------------------------------------
create table if not exists public.complaint_tasks (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  response_id uuid not null references public.responses (id) on delete cascade,
  analysis_id uuid references public.feedback_analysis (id) on delete set null,
  title text not null,
  description text not null default '',
  category text not null default 'General',
  priority text not null default 'medium'
    check (priority in ('low', 'medium', 'high', 'critical')),
  status text not null default 'open'
    check (status in ('open', 'in_progress', 'resolved', 'closed')),
  assigned_to uuid references public.profiles (id) on delete set null,
  due_at timestamptz,
  resolution_notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (response_id)
);

create index if not exists complaint_tasks_org_status_idx
  on public.complaint_tasks (org_id, status, created_at desc);
create index if not exists complaint_tasks_assignee_idx
  on public.complaint_tasks (assigned_to)
  where assigned_to is not null;

alter table public.complaint_tasks enable row level security;

drop policy if exists complaint_tasks_select_member on public.complaint_tasks;
create policy complaint_tasks_select_member on public.complaint_tasks
  for select using (org_id = public.current_org_id());

drop policy if exists complaint_tasks_update_member on public.complaint_tasks;
create policy complaint_tasks_update_member on public.complaint_tasks
  for update using (
    org_id = public.current_org_id()
    and (
      public.is_org_admin()
      or assigned_to = auth.uid()
    )
  )
  with check (
    org_id = public.current_org_id()
    and (
      assigned_to is null
      or exists (
        select 1 from public.profiles p
        where p.id = assigned_to and p.org_id = public.current_org_id()
      )
    )
  );

-- ---------------------------------------------------------------------------
-- In-app notifications
-- ---------------------------------------------------------------------------
create table if not exists public.notification_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  type text not null default 'complaint_task',
  title text not null,
  body text not null default '',
  payload jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists notification_events_user_idx
  on public.notification_events (user_id, created_at desc);
create index if not exists notification_events_unread_idx
  on public.notification_events (user_id)
  where read_at is null;

alter table public.notification_events enable row level security;

drop policy if exists notification_events_select_own on public.notification_events;
create policy notification_events_select_own on public.notification_events
  for select using (
    user_id = auth.uid() and org_id = public.current_org_id()
  );

drop policy if exists notification_events_update_own on public.notification_events;
create policy notification_events_update_own on public.notification_events
  for update using (
    user_id = auth.uid() and org_id = public.current_org_id()
  )
  with check (
    user_id = auth.uid() and org_id = public.current_org_id()
  );

-- ---------------------------------------------------------------------------
-- Enqueue on response insert (never blocks / fails the insert)
-- ---------------------------------------------------------------------------
create or replace function public.enqueue_feedback_ai_job()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org_id uuid;
  v_enabled boolean;
begin
  select f.org_id, coalesce(o.ai_feedback_enabled, true)
    into v_org_id, v_enabled
  from public.forms f
  join public.organizations o on o.id = f.org_id
  where f.id = new.form_id;

  if v_org_id is null then
    return new;
  end if;

  if not v_enabled then
    insert into public.feedback_processing_jobs (org_id, response_id, status, skip_reason)
    values (v_org_id, new.id, 'skipped', 'org_ai_disabled')
    on conflict (response_id) do nothing;
    return new;
  end if;

  insert into public.feedback_processing_jobs (org_id, response_id, status)
  values (v_org_id, new.id, 'pending')
  on conflict (response_id) do nothing;

  return new;
exception when others then
  -- Never fail the customer response insert because of AI queue issues.
  return new;
end;
$$;

drop trigger if exists trg_enqueue_feedback_ai_job on public.responses;
create trigger trg_enqueue_feedback_ai_job
  after insert on public.responses
  for each row execute function public.enqueue_feedback_ai_job();

-- ---------------------------------------------------------------------------
-- Service-role helpers for Edge Function
-- ---------------------------------------------------------------------------
create or replace function public.claim_feedback_ai_jobs(p_limit integer default 5)
returns setof public.feedback_processing_jobs
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.role() <> 'service_role' and current_user not in ('postgres', 'supabase_admin') then
    raise exception 'FORBIDDEN: claim_feedback_ai_jobs requires service_role';
  end if;

  return query
  with candidates as (
    select j.id
    from public.feedback_processing_jobs j
    where j.status in ('pending', 'failed')
      and j.attempts < j.max_attempts
    order by j.created_at asc
    limit greatest(1, least(coalesce(p_limit, 5), 20))
    for update skip locked
  )
  update public.feedback_processing_jobs j
  set
    status = 'processing',
    attempts = j.attempts + 1,
    updated_at = now()
  from candidates c
  where j.id = c.id
  returning j.*;
end;
$$;

revoke all on function public.claim_feedback_ai_jobs(integer) from public, anon, authenticated;
grant execute on function public.claim_feedback_ai_jobs(integer) to service_role;

create or replace function public.org_ai_analysis_count_this_month(p_org_id uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer
  from public.feedback_analysis a
  where a.org_id = p_org_id
    and a.created_at >= date_trunc('month', now() at time zone 'utc');
$$;

revoke all on function public.org_ai_analysis_count_this_month(uuid) from public, anon;
grant execute on function public.org_ai_analysis_count_this_month(uuid) to authenticated, service_role;
