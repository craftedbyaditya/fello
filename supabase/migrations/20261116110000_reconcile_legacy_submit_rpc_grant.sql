-- Hosted Kaydo schemas may retain the pre-P0.1 five-argument overload after
-- the hardened six-argument submit_public_response function is introduced.
-- It must never remain callable by browser roles: that route lacks the Edge
-- Function's server-side Turnstile verification.
revoke all on function public.submit_public_response(uuid, jsonb, jsonb, text, uuid)
  from public, anon, authenticated;

-- The six-argument function is the only submission RPC used by the Edge
-- Function. Browser roles remain revoked; service_role is its sole caller.
revoke all on function public.submit_public_response(uuid, jsonb, jsonb, text, uuid, text)
  from public, anon, authenticated;
grant execute on function public.submit_public_response(uuid, jsonb, jsonb, text, uuid, text)
  to service_role;
