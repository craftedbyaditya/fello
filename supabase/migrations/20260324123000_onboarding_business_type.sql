-- Onboarding: optional business_type + persisted workspace setup completion.
-- Existing organisations are backfilled so they skip the new onboarding wizard.

alter table public.organizations
  add column if not exists business_type text;

alter table public.organizations
  add column if not exists onboarding_completed_at timestamptz;

update public.organizations
set onboarding_completed_at = coalesce(onboarding_completed_at, created_at)
where onboarding_completed_at is null;

-- Signup creates a placeholder workspace; the user names it during onboarding.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  new_org_id uuid;
  org_name text;
  org_slug text;
  display text;
begin
  org_name := coalesce(
    nullif(trim(new.raw_user_meta_data->>'organization_name'), ''),
    'My workspace'
  );
  display := coalesce(
    nullif(trim(new.raw_user_meta_data->>'display_name'), ''),
    split_part(new.email, '@', 1)
  );
  org_slug := lower(regexp_replace(org_name, '[^a-zA-Z0-9]+', '-', 'g'));
  org_slug := trim(both '-' from org_slug);
  if org_slug = '' then
    org_slug := substr(new.id::text, 1, 8);
  end if;
  while exists(select 1 from public.organizations where slug = org_slug) loop
    org_slug := org_slug || '-' || substr(gen_random_uuid()::text, 1, 4);
  end loop;

  insert into public.organizations (name, slug)
  values (org_name, org_slug)
  returning id into new_org_id;

  insert into public.profiles (id, org_id, display_name, role)
  values (new.id, new_org_id, display, 'admin');

  return new;
end;
$$;
