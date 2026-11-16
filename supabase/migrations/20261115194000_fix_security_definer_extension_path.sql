-- pgcrypto is installed in the trusted `extensions` schema on Supabase.
-- These SECURITY DEFINER functions intentionally use a fixed search_path; add
-- that schema explicitly so their digest() calls work without exposing caller
-- controlled schemas.
alter function public.create_org_api_key(text)
  set search_path = public, extensions;

alter function public.resolve_org_api_key(text)
  set search_path = public, extensions;

alter function public.submit_public_response(uuid, jsonb, jsonb, text, uuid, text)
  set search_path = public, extensions;
