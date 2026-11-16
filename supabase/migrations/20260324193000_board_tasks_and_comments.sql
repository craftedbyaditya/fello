-- Board support: manual tasks + comments. Reuses complaint_tasks.
-- Maps: open=Backlog, in_progress=In Progress, resolved/closed=Done.

-- ---------------------------------------------------------------------------
-- Manual tasks: response_id optional; keep unique only when present
-- ---------------------------------------------------------------------------
alter table public.complaint_tasks
  alter column response_id drop not null;

-- Postgres UNIQUE already allows multiple NULLs; keep constraint as-is.
-- Add creator / source for Board attribution (null created_by = Kaydo AI).
alter table public.complaint_tasks
  add column if not exists created_by uuid references public.profiles (id) on delete set null;

alter table public.complaint_tasks
  add column if not exists source text not null default 'ai'
    check (source in ('ai', 'manual'));

create index if not exists complaint_tasks_org_created_idx
  on public.complaint_tasks (org_id, created_at desc);

-- Org members may insert manual tasks (AI inserts use service_role).
drop policy if exists complaint_tasks_insert_member on public.complaint_tasks;
create policy complaint_tasks_insert_member on public.complaint_tasks
  for insert with check (
    org_id = public.current_org_id()
    and source = 'manual'
    and created_by = auth.uid()
    and response_id is null
    and status = 'open'
  );

-- Broaden updates: any org member can move/edit board tasks in their org.
drop policy if exists complaint_tasks_update_member on public.complaint_tasks;
create policy complaint_tasks_update_member on public.complaint_tasks
  for update using (org_id = public.current_org_id())
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

-- Trusted manual create (sets creator; rejects spoofed created_by)
create or replace function public.create_manual_board_task(
  p_title text,
  p_description text default ''
)
returns public.complaint_tasks
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org uuid := public.current_org_id();
  v_title text := trim(coalesce(p_title, ''));
  v_desc text := trim(coalesce(p_description, ''));
  v_row public.complaint_tasks;
begin
  if v_org is null or auth.uid() is null then
    raise exception 'FORBIDDEN: Not authenticated';
  end if;
  if char_length(v_title) < 1 or char_length(v_title) > 200 then
    raise exception 'INVALID: Title must be 1–200 characters.';
  end if;
  if char_length(v_desc) > 4000 then
    raise exception 'INVALID: Description must be at most 4000 characters.';
  end if;

  insert into public.complaint_tasks (
    org_id,
    response_id,
    analysis_id,
    title,
    description,
    category,
    priority,
    status,
    created_by,
    source
  ) values (
    v_org,
    null,
    null,
    v_title,
    v_desc,
    'General',
    'medium',
    'open',
    auth.uid(),
    'manual'
  )
  returning * into v_row;

  return v_row;
end;
$$;

revoke all on function public.create_manual_board_task(text, text) from public, anon;
grant execute on function public.create_manual_board_task(text, text) to authenticated;

create or replace function public.update_board_task(
  p_task_id uuid,
  p_title text default null,
  p_description text default null,
  p_status text default null
)
returns public.complaint_tasks
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org uuid := public.current_org_id();
  v_row public.complaint_tasks;
  v_title text;
  v_desc text;
begin
  if v_org is null or auth.uid() is null then
    raise exception 'FORBIDDEN: Not authenticated';
  end if;

  select * into v_row
  from public.complaint_tasks
  where id = p_task_id and org_id = v_org
  for update;

  if not found then
    raise exception 'NOT_FOUND: Task not found.';
  end if;

  if p_status is not null and p_status not in ('open', 'in_progress', 'resolved', 'closed') then
    raise exception 'INVALID: Bad status.';
  end if;

  v_title := coalesce(nullif(trim(p_title), ''), v_row.title);
  v_desc := case
    when p_description is null then v_row.description
    else trim(p_description)
  end;

  if char_length(v_title) < 1 or char_length(v_title) > 200 then
    raise exception 'INVALID: Title must be 1–200 characters.';
  end if;
  if char_length(v_desc) > 4000 then
    raise exception 'INVALID: Description must be at most 4000 characters.';
  end if;

  update public.complaint_tasks
  set
    title = v_title,
    description = v_desc,
    status = coalesce(p_status, status),
    updated_at = now()
  where id = p_task_id
  returning * into v_row;

  return v_row;
end;
$$;

revoke all on function public.update_board_task(uuid, text, text, text) from public, anon;
grant execute on function public.update_board_task(uuid, text, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Task comments
-- ---------------------------------------------------------------------------
create table if not exists public.task_comments (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  task_id uuid not null references public.complaint_tasks (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now(),
  client_mutation_id uuid,
  constraint task_comments_body_len check (char_length(trim(body)) between 1 and 2000)
);

create unique index if not exists task_comments_mutation_uidx
  on public.task_comments (task_id, author_id, client_mutation_id)
  where client_mutation_id is not null;

create index if not exists task_comments_task_idx
  on public.task_comments (task_id, created_at asc);

alter table public.task_comments enable row level security;

drop policy if exists task_comments_select_member on public.task_comments;
create policy task_comments_select_member on public.task_comments
  for select using (org_id = public.current_org_id());

drop policy if exists task_comments_insert_member on public.task_comments;
create policy task_comments_insert_member on public.task_comments
  for insert with check (
    org_id = public.current_org_id()
    and author_id = auth.uid()
    and exists (
      select 1 from public.complaint_tasks t
      where t.id = task_id and t.org_id = public.current_org_id()
    )
  );

-- No update/delete for comments (append-only).

create or replace function public.add_task_comment(
  p_task_id uuid,
  p_body text,
  p_client_mutation_id uuid default null
)
returns public.task_comments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org uuid := public.current_org_id();
  v_body text := trim(coalesce(p_body, ''));
  v_task public.complaint_tasks;
  v_row public.task_comments;
begin
  if v_org is null or auth.uid() is null then
    raise exception 'FORBIDDEN: Not authenticated';
  end if;
  if char_length(v_body) < 1 or char_length(v_body) > 2000 then
    raise exception 'INVALID: Comment must be 1–2000 characters.';
  end if;

  select * into v_task
  from public.complaint_tasks
  where id = p_task_id and org_id = v_org;

  if not found then
    raise exception 'NOT_FOUND: Task not found.';
  end if;

  if p_client_mutation_id is not null then
    select * into v_row
    from public.task_comments
    where task_id = p_task_id
      and author_id = auth.uid()
      and client_mutation_id = p_client_mutation_id;
    if found then
      return v_row;
    end if;
  end if;

  insert into public.task_comments (
    org_id, task_id, author_id, body, client_mutation_id
  ) values (
    v_org, p_task_id, auth.uid(), v_body, p_client_mutation_id
  )
  returning * into v_row;

  return v_row;
end;
$$;

revoke all on function public.add_task_comment(uuid, text, uuid) from public, anon;
grant execute on function public.add_task_comment(uuid, text, uuid) to authenticated;

-- Reclaim stuck AI jobs (processing > 10 minutes → failed for retry)
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

  -- Recover stale processing rows so Board AI tasks can still be created.
  update public.feedback_processing_jobs
  set status = 'failed',
      last_error = coalesce(last_error, 'stale_processing_reclaimed'),
      updated_at = now()
  where status = 'processing'
    and updated_at < now() - interval '10 minutes'
    and attempts < max_attempts;

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
