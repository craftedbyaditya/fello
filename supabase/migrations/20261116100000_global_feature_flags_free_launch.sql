-- P0.3: global, operator-controlled launch switches. These are deliberately
-- independent of organization plans: a valid paid entitlement never changes
-- when a sales/feature switch changes.

create table if not exists public.platform_operators (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  created_by uuid references public.profiles(id) on delete set null
);
alter table public.platform_operators enable row level security;
-- No client policies. Bootstrap and operator assignment are service-role / SQL only.

create table if not exists public.global_feature_flags (
  key text primary key check (key ~ '^[a-z][a-z0-9_]{2,79}$'),
  enabled boolean not null default false,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles(id) on delete set null
);
alter table public.global_feature_flags enable row level security;
-- The safe read surface is the RPC below; clients cannot write rows directly.

create table if not exists public.global_feature_flag_audit (
  id uuid primary key default gen_random_uuid(),
  flag_key text not null,
  previous_value boolean not null,
  new_value boolean not null,
  actor_id uuid references public.profiles(id) on delete set null,
  changed_at timestamptz not null default now()
);
alter table public.global_feature_flag_audit enable row level security;

insert into public.global_feature_flags(key, enabled) values
  ('signup_enabled', true),
  ('feedback_forms_enabled', true),
  ('feedback_submissions_enabled', true),
  ('analytics_enabled', true),
  ('task_board_enabled', false),
  ('ai_processing_enabled', false),
  ('reviews_api_enabled', false),
  ('team_invites_enabled', false),
  ('billing_enabled', false),
  ('growth_plan_sales_enabled', false),
  ('pro_plan_sales_enabled', false)
on conflict (key) do nothing;

create or replace function public.is_platform_operator()
returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.platform_operators where user_id = auth.uid());
$$;

create or replace function public.is_feature_enabled(p_key text)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select enabled from public.global_feature_flags where key = p_key), false);
$$;

create or replace function public.get_launch_feature_flags()
returns table(key text, enabled boolean)
language sql stable security definer set search_path = public as $$
  select f.key, f.enabled from public.global_feature_flags f order by f.key;
$$;
revoke all on function public.get_launch_feature_flags() from public;
grant execute on function public.get_launch_feature_flags() to anon, authenticated;

create or replace function public.set_global_feature_flag(p_key text, p_enabled boolean)
returns void language plpgsql security definer set search_path = public as $$
declare v_old boolean;
begin
  if not public.is_platform_operator() then raise exception 'FORBIDDEN: platform operator required'; end if;
  select enabled into v_old from public.global_feature_flags where key = p_key for update;
  if not found then raise exception 'NOT_FOUND: feature flag not found'; end if;
  if v_old is distinct from p_enabled then
    update public.global_feature_flags set enabled=p_enabled, updated_at=now(), updated_by=auth.uid() where key=p_key;
    insert into public.global_feature_flag_audit(flag_key, previous_value, new_value, actor_id)
    values(p_key, v_old, p_enabled, auth.uid());
  end if;
end;
$$;
revoke all on function public.set_global_feature_flag(text, boolean) from public, anon;
grant execute on function public.set_global_feature_flag(text, boolean) to authenticated;

-- Mutation-sensitive launch gates. They remain server-side even if an old
-- Flutter build or direct PostgREST call tries to bypass hidden navigation.
create or replace function public.enforce_forms_feature_flag()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not public.is_feature_enabled('feedback_forms_enabled') then raise exception 'FEATURE_DISABLED: feedback forms are unavailable'; end if;
  return new;
end;
$$;
drop trigger if exists trg_enforce_forms_feature_flag on public.forms;
create trigger trg_enforce_forms_feature_flag before insert on public.forms for each row execute function public.enforce_forms_feature_flag();

create or replace function public.enforce_submission_feature_flag()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not public.is_feature_enabled('feedback_submissions_enabled') then raise exception 'FEATURE_DISABLED: feedback submissions are unavailable'; end if;
  return new;
end;
$$;
drop trigger if exists trg_enforce_submission_feature_flag on public.responses;
create trigger trg_enforce_submission_feature_flag before insert on public.responses for each row execute function public.enforce_submission_feature_flag();

create or replace function public.enforce_team_invites_feature_flag()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not public.is_feature_enabled('team_invites_enabled') then raise exception 'FEATURE_DISABLED: team invites are unavailable'; end if;
  return new;
end;
$$;
drop trigger if exists trg_enforce_team_invites_feature_flag on public.organization_invites;
create trigger trg_enforce_team_invites_feature_flag before insert on public.organization_invites for each row execute function public.enforce_team_invites_feature_flag();

-- Reviews API remains Pro-only and additionally requires the global release flag.
create or replace function public.org_allows_reviews_api(p_org_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_feature_enabled('reviews_api_enabled')
    and coalesce(public.org_entitlement_plan(p_org_id), 'free') = 'pro';
$$;

-- The worker must not claim global jobs while AI is globally off.
create or replace function public.claim_feedback_ai_jobs(p_limit integer default 5)
returns setof public.feedback_processing_jobs
language plpgsql security definer set search_path = public as $$
begin
  if auth.role() <> 'service_role' and current_user not in ('postgres', 'supabase_admin') then
    raise exception 'FORBIDDEN: claim_feedback_ai_jobs requires service_role';
  end if;
  if not public.is_feature_enabled('ai_processing_enabled') then return; end if;
  return query
  with candidates as (
    select j.id from public.feedback_processing_jobs j
    where j.status in ('pending','failed') and j.attempts < j.max_attempts
    order by j.created_at asc
    limit greatest(1, least(coalesce(p_limit,5),20)) for update skip locked
  )
  update public.feedback_processing_jobs j set status='processing', attempts=j.attempts+1, updated_at=now()
  from candidates c where j.id=c.id returning j.*;
end;
$$;
revoke all on function public.claim_feedback_ai_jobs(integer) from public, anon, authenticated;
grant execute on function public.claim_feedback_ai_jobs(integer) to service_role;

revoke all on function public.is_platform_operator() from public, anon;
grant execute on function public.is_platform_operator() to authenticated, service_role;
revoke all on function public.is_feature_enabled(text) from public, anon;
grant execute on function public.is_feature_enabled(text) to authenticated, service_role;
revoke all on function public.enforce_forms_feature_flag() from public, anon, authenticated;
revoke all on function public.enforce_submission_feature_flag() from public, anon, authenticated;
revoke all on function public.enforce_team_invites_feature_flag() from public, anon, authenticated;
