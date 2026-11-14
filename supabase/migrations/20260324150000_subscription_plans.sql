-- Monthly subscription plans + hard limits on surveys & responses.

alter table public.organizations
  add column if not exists plan_id text not null default 'free'
    check (plan_id in ('free', 'starter', 'growth', 'custom'));

alter table public.organizations
  add column if not exists plan_status text not null default 'active'
    check (plan_status in ('active', 'past_due', 'canceled'));

-- Backfill existing workspaces onto Starter so live orgs keep working.
update public.organizations
set plan_id = 'starter'
where plan_id = 'free';

create or replace function public.plan_max_surveys(p_plan text)
returns int
language sql
immutable
as $$
  select case p_plan
    when 'free' then 1
    when 'starter' then 2
    when 'growth' then 10
    when 'custom' then null  -- unlimited
    else 1
  end;
$$;

create or replace function public.plan_max_responses(p_plan text)
returns int
language sql
immutable
as $$
  select case p_plan
    when 'free' then 50
    when 'starter' then 250
    when 'growth' then 2500
    when 'custom' then 10000
    else 50
  end;
$$;

create or replace function public.month_period_start(ts timestamptz default now())
returns timestamptz
language sql
immutable
as $$
  select date_trunc('month', ts at time zone 'utc') at time zone 'utc';
$$;

create or replace function public.org_response_count_this_month(p_org_id uuid)
returns int
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::int
  from public.responses r
  join public.forms f on f.id = r.form_id
  where f.org_id = p_org_id
    and r.submitted_at >= public.month_period_start(now());
$$;

create or replace function public.org_survey_count(p_org_id uuid)
returns int
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::int from public.forms where org_id = p_org_id;
$$;

-- Block creating surveys past plan limit.
create or replace function public.enforce_form_plan_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  org_plan text;
  max_surveys int;
  current_count int;
begin
  select plan_id into org_plan from public.organizations where id = new.org_id;
  max_surveys := public.plan_max_surveys(coalesce(org_plan, 'free'));
  if max_surveys is null then
    return new;
  end if;
  current_count := public.org_survey_count(new.org_id);
  -- On INSERT, count does not include the new row yet.
  if tg_op = 'INSERT' and current_count >= max_surveys then
    raise exception 'PLAN_LIMIT_SURVEYS: Your plan allows % surveys. Upgrade to add more.', max_surveys;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_enforce_form_plan_limit on public.forms;
create trigger trg_enforce_form_plan_limit
  before insert on public.forms
  for each row execute function public.enforce_form_plan_limit();

-- Block responses past monthly plan limit.
create or replace function public.enforce_response_plan_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  org uuid;
  org_plan text;
  max_responses int;
  current_count int;
begin
  select f.org_id into org from public.forms f where f.id = new.form_id;
  if org is null then
    raise exception 'Form not found';
  end if;
  select plan_id into org_plan from public.organizations where id = org;
  max_responses := public.plan_max_responses(coalesce(org_plan, 'free'));
  if max_responses is null then
    return new;
  end if;
  current_count := public.org_response_count_this_month(org);
  if current_count >= max_responses then
    raise exception 'PLAN_LIMIT_RESPONSES: This workspace has reached its monthly response limit. Please try again next month.';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_enforce_response_plan_limit on public.responses;
create trigger trg_enforce_response_plan_limit
  before insert on public.responses
  for each row execute function public.enforce_response_plan_limit();

-- Admins can update their org plan_id (payment can replace this later).
drop policy if exists org_update_member on public.organizations;
create policy org_update_member on public.organizations
  for update using (
    id = public.current_org_id()
    and public.is_org_admin()
  );

grant execute on function public.org_response_count_this_month(uuid) to authenticated;
grant execute on function public.org_survey_count(uuid) to authenticated;
