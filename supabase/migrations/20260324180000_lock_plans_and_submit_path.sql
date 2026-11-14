-- 1) Lock plan_id / plan_status: clients cannot self-upgrade entitlements.
--    Payment webhooks (service_role) or DB owners may still change plans later.
-- 2) Close public submit RPC bypass: only service_role may call
--    submit_public_response (Edge Function after Turnstile verify).

-- ---------------------------------------------------------------------------
-- Plan entitlement lock
-- ---------------------------------------------------------------------------
create or replace function public.prevent_client_plan_change()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if tg_op = 'UPDATE'
     and (
       new.plan_id is distinct from old.plan_id
       or coalesce(new.plan_status, '') is distinct from coalesce(old.plan_status, '')
     ) then
    -- service_role = future payment webhook; postgres roles = migrations / SQL editor
    if auth.role() = 'service_role'
       or current_user in ('postgres', 'supabase_admin') then
      return new;
    end if;
    raise exception
      'PLAN_LOCKED: Subscription changes are managed by billing. Paid plans cannot be activated from the app yet.';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_prevent_client_plan_change on public.organizations;
create trigger trg_prevent_client_plan_change
  before update on public.organizations
  for each row execute function public.prevent_client_plan_change();

-- ---------------------------------------------------------------------------
-- Public submit: RPC only via Edge Function (service_role)
-- ---------------------------------------------------------------------------
revoke all on function public.submit_public_response(uuid, jsonb, jsonb, text, uuid)
  from public, anon, authenticated;

grant execute on function public.submit_public_response(uuid, jsonb, jsonb, text, uuid)
  to service_role;
