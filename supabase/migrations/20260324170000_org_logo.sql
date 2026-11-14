-- Workspace logo: optional URL + toggle to show on public forms.

alter table public.organizations
  add column if not exists logo_url text;

alter table public.organizations
  add column if not exists show_logo_on_forms boolean not null default false;

-- Anon can read logo fields only when the org opts in and has a published form.
drop policy if exists org_select_public_logo on public.organizations;
create policy org_select_public_logo on public.organizations
  for select using (
    show_logo_on_forms = true
    and nullif(trim(logo_url), '') is not null
    and exists (
      select 1
      from public.forms f
      where f.org_id = organizations.id
        and f.status = 'published'
    )
  );
