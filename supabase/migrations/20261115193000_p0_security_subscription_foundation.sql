-- P0 security, privacy and subscription foundation.
-- Additive only: legacy `custom` plans remain readable until an operator reviews
-- them, so no existing customer is silently downgraded.

-- ---------------------------------------------------------------------------
-- Three-plan catalog and safe legacy mapping
-- ---------------------------------------------------------------------------
alter table public.organizations add column if not exists legacy_plan_id text;
alter table public.organizations add column if not exists subscription_id uuid;

create table if not exists public.subscription_migration_reviews (
  org_id uuid primary key references public.organizations(id) on delete cascade,
  legacy_plan_id text not null,
  reason text not null,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id) on delete set null
);
alter table public.subscription_migration_reviews enable row level security;
-- Deliberately no client policies: this is an operator reconciliation queue.

-- Old Starter maps upward to Growth; old Growth maps upward to Pro.  Custom
-- might have unlimited forms, so it is retained and explicitly queued.
update public.organizations
set
  legacy_plan_id = plan_id,
  plan_id = case plan_id
    when 'starter' then 'growth'
    when 'growth' then 'pro'
    else plan_id
  end
where plan_id in ('starter', 'growth');
insert into public.subscription_migration_reviews (org_id, legacy_plan_id, reason)
select id, plan_id, 'Legacy Custom plan may have limits above Pro; operator review required before remapping.'
from public.organizations
where plan_id = 'custom'
on conflict (org_id) do nothing;

alter table public.organizations drop constraint if exists organizations_plan_id_check;
alter table public.organizations add constraint organizations_plan_id_check
  check (plan_id in ('free', 'growth', 'pro', 'custom'));

create or replace function public.plan_max_surveys(p_plan text) returns int language sql immutable as $$
  select case p_plan when 'free' then 1 when 'growth' then 3 when 'pro' then 10 when 'custom' then null else 1 end;
$$;
create or replace function public.plan_max_responses(p_plan text) returns int language sql immutable as $$
  select case p_plan when 'free' then 75 when 'growth' then 1000 when 'pro' then 5000 when 'custom' then 10000 else 75 end;
$$;
create or replace function public.plan_max_members(p_plan text) returns int language sql immutable as $$
  select case p_plan when 'free' then 1 when 'growth' then 5 when 'pro' then 15 when 'custom' then null else 1 end;
$$;
create or replace function public.plan_max_ai_analyses(p_plan text) returns int language sql immutable as $$
  select case p_plan when 'free' then 0 when 'growth' then 300 when 'pro' then 1500 when 'custom' then 10000 else 0 end;
$$;

-- Subscription policy: active and past-due workspaces retain their recorded
-- plan while payment is being recovered; canceled/unpaid workspaces fall back
-- to Free entitlements after their provider/webhook updates plan_status.
create or replace function public.org_entitlement_plan(p_org_id uuid) returns text
language sql stable security definer set search_path = public as $$
  select case when coalesce(plan_status, 'active') in ('active', 'past_due') then plan_id else 'free' end
  from public.organizations where id = p_org_id;
$$;

-- Pro only. This function is used by both key management and the edge function.
create or replace function public.org_allows_reviews_api(p_org_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.org_entitlement_plan(p_org_id), 'free') = 'pro';
$$;

-- ---------------------------------------------------------------------------
-- Provider-independent subscription records. Only service role / DB owners can
-- modify lifecycle data; a future verified webhook is the intended writer.
-- ---------------------------------------------------------------------------
create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null unique references public.organizations(id) on delete cascade,
  provider text,
  provider_customer_id text,
  provider_subscription_id text,
  plan_id text not null default 'free' check (plan_id in ('free', 'growth', 'pro', 'custom')),
  status text not null default 'active' check (status in ('active', 'trialing', 'past_due', 'canceled', 'unpaid')),
  billing_interval text not null default 'month' check (billing_interval in ('month', 'year')),
  current_period_start timestamptz,
  current_period_end timestamptz,
  cancel_at_period_end boolean not null default false,
  canceled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(provider, provider_subscription_id)
);
alter table public.subscriptions enable row level security;
create policy subscriptions_select_member on public.subscriptions for select using (org_id = public.current_org_id());

create table if not exists public.subscription_webhook_events (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  provider_event_id text not null,
  org_id uuid references public.organizations(id) on delete set null,
  payload jsonb not null,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  processing_error text,
  unique(provider, provider_event_id)
);
alter table public.subscription_webhook_events enable row level security;
create table if not exists public.subscription_audit_logs (
  id uuid primary key default gen_random_uuid(), org_id uuid not null references public.organizations(id) on delete cascade,
  subscription_id uuid references public.subscriptions(id) on delete set null, event_type text not null,
  details jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);
alter table public.subscription_audit_logs enable row level security;

-- ---------------------------------------------------------------------------
-- Atomic quotas: a counter row serializes concurrent response inserts.
-- Calendar UTC months remain the documented usage period.
-- ---------------------------------------------------------------------------
create table if not exists public.org_monthly_usage (
  org_id uuid not null references public.organizations(id) on delete cascade,
  period_start timestamptz not null,
  response_count integer not null default 0 check (response_count >= 0),
  ai_analysis_count integer not null default 0 check (ai_analysis_count >= 0),
  primary key (org_id, period_start)
);
alter table public.org_monthly_usage enable row level security;

create or replace function public.enforce_response_plan_limit() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_org uuid; v_max int; v_count int; v_period timestamptz := public.month_period_start(now());
begin
  select org_id into v_org from public.forms where id = new.form_id;
  if v_org is null then raise exception 'FORM_UNAVAILABLE'; end if;
  select public.plan_max_responses(public.org_entitlement_plan(v_org)) into v_max;
  if v_max is null then return new; end if;
  insert into public.org_monthly_usage(org_id, period_start, response_count) values(v_org, v_period, 1)
  on conflict (org_id, period_start) do update set response_count = public.org_monthly_usage.response_count + 1
  returning response_count into v_count;
  if v_count > v_max then
    update public.org_monthly_usage set response_count = response_count - 1 where org_id = v_org and period_start = v_period;
    raise exception 'PLAN_LIMIT_RESPONSES';
  end if;
  return new;
end;
$$;

create or replace function public.enforce_form_plan_limit() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_max int; v_count int;
begin
  v_max := public.plan_max_surveys(public.org_entitlement_plan(new.org_id));
  if v_max is null then return new; end if;
  select count(*) into v_count from public.forms where org_id = new.org_id;
  if tg_op = 'INSERT' and v_count >= v_max then raise exception 'PLAN_LIMIT_SURVEYS'; end if;
  return new;
end;
$$;

create or replace function public.enforce_logo_plan_gate() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_plan text := case when tg_op = 'INSERT' then coalesce(new.plan_id, 'free') else public.org_entitlement_plan(old.id) end;
begin
  if v_plan = 'free' then
    if new.show_logo_on_forms then raise exception 'PLAN_LIMIT_LOGO'; end if;
    new.show_logo_on_forms := false;
  end if;
  return new;
end;
$$;
revoke all on function public.enforce_form_plan_limit() from public, anon, authenticated;
revoke all on function public.enforce_response_plan_limit() from public, anon, authenticated;
revoke all on function public.enforce_logo_plan_gate() from public, anon, authenticated;

-- Membership is guarded for both pending invitations and accepted users.
create or replace function public.enforce_team_member_limit() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_org uuid := new.org_id; v_max int; v_count int;
begin
  -- Serialise concurrent invitations for one workspace.
  perform 1 from public.organizations where id = v_org for update;
  select public.plan_max_members(public.org_entitlement_plan(v_org)) into v_max;
  if v_max is null then return new; end if;
  select (select count(*) from public.profiles where org_id = v_org) +
         (select count(*) from public.organization_invites where org_id = v_org and status = 'pending') into v_count;
  if v_count >= v_max then raise exception 'PLAN_LIMIT_TEAM_MEMBERS'; end if;
  return new;
end;
$$;
drop trigger if exists trg_enforce_invite_plan_limit on public.organization_invites;
create trigger trg_enforce_invite_plan_limit before insert on public.organization_invites for each row execute function public.enforce_team_member_limit();

-- Atomically reserve an AI analysis before a worker sends customer feedback to
-- the configured provider. A false return leaves the durable job skipped.
create or replace function public.consume_ai_analysis_quota(p_org_id uuid)
returns boolean language plpgsql security definer set search_path = public as $$
declare v_limit int; v_count int; v_period timestamptz := public.month_period_start(now());
begin
  if auth.role() <> 'service_role' and current_user not in ('postgres','supabase_admin') then raise exception 'FORBIDDEN'; end if;
  select public.plan_max_ai_analyses(public.org_entitlement_plan(p_org_id)) into v_limit;
  if coalesce(v_limit, 0) <= 0 then return false; end if;
  insert into public.org_monthly_usage(org_id, period_start, ai_analysis_count) values(p_org_id, v_period, 1)
  on conflict (org_id, period_start) do update set ai_analysis_count = public.org_monthly_usage.ai_analysis_count + 1
  returning ai_analysis_count into v_count;
  if v_count > v_limit then
    update public.org_monthly_usage set ai_analysis_count = ai_analysis_count - 1 where org_id = p_org_id and period_start = v_period;
    return false;
  end if;
  return true;
end;
$$;
revoke all on function public.consume_ai_analysis_quota(uuid) from public, anon, authenticated;
grant execute on function public.consume_ai_analysis_quota(uuid) to service_role;

-- Public review text is a deliberate, admin-set field. Raw answers never leave
-- the product through the Reviews API.
alter table public.responses add column if not exists public_review_text text;
alter table public.responses add column if not exists public_review_rating integer check (public_review_rating between 1 and 5);
alter table public.responses add column if not exists public_review_published_at timestamptz;
create or replace function public.enforce_public_review_fields() returns trigger language plpgsql as $$
begin
  -- Existing admin publishing continues to work. A response is eligible for
  -- the external API only when an admin also supplies explicit review text;
  -- the API filters null text rather than falling back to raw answers.
  if new.is_public and old.is_public is distinct from true then new.public_review_published_at := now(); end if;
  return new;
end;
$$;
drop trigger if exists trg_enforce_public_review_fields on public.responses;
create trigger trg_enforce_public_review_fields before update of is_public, public_review_text, public_review_rating on public.responses for each row execute function public.enforce_public_review_fields();

-- Server-only public submit hardening. The Edge Function supplies a Cloudflare
-- connection IP; browser identifiers are retained only as non-authoritative telemetry.
alter table public.submission_rate_limits add column if not exists source_ip_hash text;
create table if not exists public.form_submission_rate_limits (
  form_id uuid not null references public.forms(id) on delete cascade,
  window_started_at timestamptz not null default now(), hit_count integer not null default 1,
  primary key (form_id)
);
alter table public.form_submission_rate_limits enable row level security;

create or replace function public.submit_public_response(
  p_form_id uuid, p_answers jsonb, p_metadata jsonb default '{}'::jsonb,
  p_client_key text default null, p_submission_id uuid default null, p_source_ip text default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare v_form public.forms%rowtype; v_response_id uuid := gen_random_uuid(); v_submission uuid;
  v_client text; v_ip_hash text; v_q record; v_val jsonb; v_key text; v_form_hits int; v_client_hits int;
begin
  if auth.role() <> 'service_role' and current_user not in ('postgres','supabase_admin') then raise exception 'FORBIDDEN'; end if;
  if pg_column_size(coalesce(p_answers, '{}'::jsonb)) > 65536 or pg_column_size(coalesce(p_metadata, '{}'::jsonb)) > 8192 then raise exception 'INVALID_SUBMISSION'; end if;
  select * into v_form from public.forms where id = p_form_id;
  if not found or v_form.status <> 'published' then raise exception 'FORM_UNAVAILABLE'; end if;
  if p_answers is null or jsonb_typeof(p_answers) <> 'object' or (select count(*) from jsonb_object_keys(p_answers)) > 100 then raise exception 'INVALID_ANSWERS'; end if;
  v_submission := coalesce(p_submission_id, gen_random_uuid());
  if exists(select 1 from public.submission_dedupe where submission_id=v_submission) then raise exception 'DUPLICATE_SUBMISSION'; end if;
  v_ip_hash := encode(digest(coalesce(nullif(trim(p_source_ip), ''), 'unavailable'), 'sha256'), 'hex');
  insert into public.form_submission_rate_limits(form_id, window_started_at, hit_count) values(p_form_id,now(),1)
  on conflict(form_id) do update set hit_count=case when form_submission_rate_limits.window_started_at <= now()-interval '10 minutes' then 1 else form_submission_rate_limits.hit_count+1 end, window_started_at=case when form_submission_rate_limits.window_started_at <= now()-interval '10 minutes' then now() else form_submission_rate_limits.window_started_at end returning hit_count into v_form_hits;
  if v_form_hits > 200 then raise exception 'RATE_LIMITED'; end if;
  insert into public.submission_rate_limits(client_key,form_id,source_ip_hash,window_started_at,hit_count) values(v_ip_hash,p_form_id,v_ip_hash,now(),1)
  on conflict(client_key,form_id) do update set hit_count=case when submission_rate_limits.window_started_at <= now()-interval '10 minutes' then 1 else submission_rate_limits.hit_count+1 end, window_started_at=case when submission_rate_limits.window_started_at <= now()-interval '10 minutes' then now() else submission_rate_limits.window_started_at end returning hit_count into v_client_hits;
  if v_client_hits > 20 then raise exception 'RATE_LIMITED'; end if;
  for v_key in select jsonb_object_keys(p_answers) loop if not exists(select 1 from public.questions q where q.form_id=p_form_id and q.id::text=v_key) then raise exception 'INVALID_ANSWERS'; end if; end loop;
  for v_q in select * from public.questions where form_id=p_form_id loop
    v_val:=p_answers->v_q.id::text;
    if v_q.required and (v_val is null or v_val='null'::jsonb or v_val='""'::jsonb or v_val='[]'::jsonb) then raise exception 'INVALID_ANSWERS'; end if;
    if v_val is null or v_val='null'::jsonb then continue; end if;
    if v_q.type in ('shortText','longText') and (jsonb_typeof(v_val)<>'string' or length(v_val #>> '{}') > case when v_q.type='shortText' then 1000 else 10000 end) then raise exception 'INVALID_ANSWERS'; end if;
    if v_q.type='starRating' and (jsonb_typeof(v_val)<>'number' or (v_val::text)::numeric<1 or (v_val::text)::numeric>5) then raise exception 'INVALID_ANSWERS'; end if;
    if v_q.type='nps' and (jsonb_typeof(v_val)<>'number' or (v_val::text)::numeric<0 or (v_val::text)::numeric>10) then raise exception 'INVALID_ANSWERS'; end if;
  end loop;
  insert into public.responses(id,form_id,metadata) values(v_response_id,p_form_id,jsonb_build_object('source_ip_hash',left(v_ip_hash,24)));
  insert into public.answers(response_id,question_id,value) select v_response_id,q.id,p_answers->q.id::text from public.questions q where q.form_id=p_form_id and p_answers?q.id::text and p_answers->q.id::text is not null and p_answers->q.id::text<>'null'::jsonb;
  insert into public.submission_dedupe(submission_id,form_id) values(v_submission,p_form_id);
  return v_response_id;
end;
$$;
revoke all on function public.submit_public_response(uuid,jsonb,jsonb,text,uuid,text) from public,anon,authenticated;
grant execute on function public.submit_public_response(uuid,jsonb,jsonb,text,uuid,text) to service_role;
