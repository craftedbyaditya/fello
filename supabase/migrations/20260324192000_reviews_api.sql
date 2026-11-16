-- Reviews API: admin-approved public reviews + org API keys (paid plans).
-- Does not change plan_id entitlements / billing tables.

-- ---------------------------------------------------------------------------
-- Admin-approved public visibility (customer submit = consent; admin publishes)
-- ---------------------------------------------------------------------------
alter table public.responses
  add column if not exists is_public boolean not null default false;

create index if not exists responses_public_form_idx
  on public.responses (form_id, submitted_at desc)
  where is_public = true;

drop policy if exists responses_update_member on public.responses;
create policy responses_update_member on public.responses
  for update using (
    exists (
      select 1 from public.forms f
      where f.id = form_id and f.org_id = public.current_org_id()
    )
    and public.is_org_admin()
  )
  with check (
    exists (
      select 1 from public.forms f
      where f.id = form_id and f.org_id = public.current_org_id()
    )
  );

-- ---------------------------------------------------------------------------
-- API keys (plaintext returned once at creation; only hash stored)
-- ---------------------------------------------------------------------------
-- pgcrypto already enabled in init (digest / gen_random_bytes).

create table if not exists public.org_api_keys (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  name text not null,
  key_prefix text not null,
  key_hash text not null unique,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  constraint org_api_keys_name_len check (char_length(trim(name)) between 1 and 80)
);

create index if not exists org_api_keys_org_idx
  on public.org_api_keys (org_id, created_at desc);

alter table public.org_api_keys enable row level security;

drop policy if exists org_api_keys_select_member on public.org_api_keys;
create policy org_api_keys_select_member on public.org_api_keys
  for select using (org_id = public.current_org_id());

-- No insert/update/delete policies for authenticated — only SECURITY DEFINER RPCs.

create or replace function public.org_allows_reviews_api(p_org_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select plan_id from public.organizations where id = p_org_id),
    'free'
  ) <> 'free';
$$;

revoke all on function public.org_allows_reviews_api(uuid) from public, anon;
grant execute on function public.org_allows_reviews_api(uuid) to authenticated, service_role;

create or replace function public.list_org_api_keys()
returns table (
  id uuid,
  name text,
  key_prefix text,
  created_at timestamptz,
  revoked_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org uuid := public.current_org_id();
begin
  if v_org is null then
    raise exception 'FORBIDDEN: Not authenticated';
  end if;
  if not public.org_allows_reviews_api(v_org) then
    raise exception 'PLAN_LIMIT_API: Reviews API requires a paid plan. Upgrade on Billing.';
  end if;

  return query
  select k.id, k.name, k.key_prefix, k.created_at, k.revoked_at
  from public.org_api_keys k
  where k.org_id = v_org
  order by k.created_at desc;
end;
$$;

revoke all on function public.list_org_api_keys() from public, anon;
grant execute on function public.list_org_api_keys() to authenticated;

create or replace function public.create_org_api_key(p_name text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org uuid := public.current_org_id();
  v_name text := trim(coalesce(p_name, ''));
  v_raw text;
  v_prefix text;
  v_hash text;
  v_id uuid;
  v_created timestamptz;
begin
  if v_org is null then
    raise exception 'FORBIDDEN: Not authenticated';
  end if;
  if not public.is_org_admin() then
    raise exception 'FORBIDDEN: Only admins can create API keys.';
  end if;
  if not public.org_allows_reviews_api(v_org) then
    raise exception 'PLAN_LIMIT_API: Reviews API requires a paid plan. Upgrade on Billing.';
  end if;
  if char_length(v_name) < 1 or char_length(v_name) > 80 then
    raise exception 'INVALID: Key name must be 1–80 characters.';
  end if;

  v_raw := 'kay_' || encode(gen_random_bytes(24), 'hex');
  v_prefix := left(v_raw, 12);
  v_hash := encode(digest(v_raw, 'sha256'), 'hex');

  insert into public.org_api_keys (org_id, name, key_prefix, key_hash, created_by)
  values (v_org, v_name, v_prefix, v_hash, auth.uid())
  returning org_api_keys.id, org_api_keys.created_at
  into v_id, v_created;

  return jsonb_build_object(
    'id', v_id,
    'name', v_name,
    'key_prefix', v_prefix,
    'api_key', v_raw,
    'created_at', v_created
  );
end;
$$;

revoke all on function public.create_org_api_key(text) from public, anon;
grant execute on function public.create_org_api_key(text) to authenticated;

create or replace function public.revoke_org_api_key(p_key_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org uuid := public.current_org_id();
  v_updated int;
begin
  if v_org is null then
    raise exception 'FORBIDDEN: Not authenticated';
  end if;
  if not public.is_org_admin() then
    raise exception 'FORBIDDEN: Only admins can revoke API keys.';
  end if;
  if not public.org_allows_reviews_api(v_org) then
    raise exception 'PLAN_LIMIT_API: Reviews API requires a paid plan. Upgrade on Billing.';
  end if;

  update public.org_api_keys
  set revoked_at = coalesce(revoked_at, now())
  where id = p_key_id and org_id = v_org and revoked_at is null;

  get diagnostics v_updated = row_count;
  if v_updated = 0 then
    -- Idempotent revoke / wrong id
    if not exists (
      select 1 from public.org_api_keys where id = p_key_id and org_id = v_org
    ) then
      raise exception 'NOT_FOUND: API key not found.';
    end if;
  end if;
end;
$$;

revoke all on function public.revoke_org_api_key(uuid) from public, anon;
grant execute on function public.revoke_org_api_key(uuid) to authenticated;

-- Service-role lookup for Edge Function (never expose hash to clients)
create or replace function public.resolve_org_api_key(p_api_key text)
returns table (
  key_id uuid,
  org_id uuid,
  plan_id text,
  revoked boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_hash text;
begin
  if auth.role() <> 'service_role' and current_user not in ('postgres', 'supabase_admin') then
    raise exception 'FORBIDDEN: resolve_org_api_key requires service_role';
  end if;

  if p_api_key is null or length(trim(p_api_key)) < 16 then
    return;
  end if;

  v_hash := encode(digest(trim(p_api_key), 'sha256'), 'hex');

  return query
  select
    k.id,
    k.org_id,
    coalesce(o.plan_id, 'free'),
    (k.revoked_at is not null)
  from public.org_api_keys k
  join public.organizations o on o.id = k.org_id
  where k.key_hash = v_hash
  limit 1;
end;
$$;

revoke all on function public.resolve_org_api_key(text) from public, anon, authenticated;
grant execute on function public.resolve_org_api_key(text) to service_role;

-- Simple durable rate limit: max 60 requests / minute / key
create table if not exists public.api_key_rate_buckets (
  key_id uuid not null references public.org_api_keys (id) on delete cascade,
  window_start timestamptz not null,
  request_count integer not null default 0,
  primary key (key_id, window_start)
);

alter table public.api_key_rate_buckets enable row level security;
-- No client policies — service_role only.

create or replace function public.consume_api_key_rate(p_key_id uuid, p_limit integer default 60)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_window timestamptz := date_trunc('minute', now());
  v_count integer;
begin
  if auth.role() <> 'service_role' and current_user not in ('postgres', 'supabase_admin') then
    raise exception 'FORBIDDEN: consume_api_key_rate requires service_role';
  end if;

  insert into public.api_key_rate_buckets (key_id, window_start, request_count)
  values (p_key_id, v_window, 1)
  on conflict (key_id, window_start)
  do update set request_count = api_key_rate_buckets.request_count + 1
  returning request_count into v_count;

  return v_count <= greatest(1, coalesce(p_limit, 60));
end;
$$;

revoke all on function public.consume_api_key_rate(uuid, integer) from public, anon, authenticated;
grant execute on function public.consume_api_key_rate(uuid, integer) to service_role;
