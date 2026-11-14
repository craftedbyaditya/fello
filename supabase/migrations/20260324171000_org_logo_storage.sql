-- Public bucket for workspace logos. Path: {org_id}/logo.{ext}
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'org-logos',
  'org-logos',
  true,
  2097152, -- 2 MB
  array['image/png', 'image/jpeg', 'image/webp', 'image/svg+xml']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Anyone can read (public forms).
drop policy if exists org_logos_public_read on storage.objects;
create policy org_logos_public_read on storage.objects
  for select using (bucket_id = 'org-logos');

-- Org admins can upload/replace under their org folder.
drop policy if exists org_logos_admin_insert on storage.objects;
create policy org_logos_admin_insert on storage.objects
  for insert with check (
    bucket_id = 'org-logos'
    and public.is_org_admin()
    and (storage.foldername(name))[1] = public.current_org_id()::text
  );

drop policy if exists org_logos_admin_update on storage.objects;
create policy org_logos_admin_update on storage.objects
  for update using (
    bucket_id = 'org-logos'
    and public.is_org_admin()
    and (storage.foldername(name))[1] = public.current_org_id()::text
  );

drop policy if exists org_logos_admin_delete on storage.objects;
create policy org_logos_admin_delete on storage.objects
  for delete using (
    bucket_id = 'org-logos'
    and public.is_org_admin()
    and (storage.foldername(name))[1] = public.current_org_id()::text
  );

-- Paid plans only may enable show_logo_on_forms.
create or replace function public.enforce_logo_plan_gate()
returns trigger
language plpgsql
as $$
begin
  if new.show_logo_on_forms is true
     and coalesce(new.plan_id, 'free') = 'free' then
    raise exception 'PLAN_LIMIT_LOGO: Workspace logo is available on paid plans. Upgrade on Billing.';
  end if;
  if coalesce(new.plan_id, 'free') = 'free' then
    new.show_logo_on_forms := false;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_enforce_logo_plan_gate on public.organizations;
create trigger trg_enforce_logo_plan_gate
  before insert or update on public.organizations
  for each row execute function public.enforce_logo_plan_gate();
