-- Admin / employee roles + org invites.
-- Sign-up without invite → admin of a new workspace.
-- Sign-up with invite_token → employee of the inviting workspace.

-- 1) Role: rename member → employee; store email on profiles for team UI
alter table public.profiles drop constraint if exists profiles_role_check;
update public.profiles set role = 'employee' where role = 'member';
alter table public.profiles
  add constraint profiles_role_check check (role in ('admin', 'employee'));

alter table public.profiles
  add column if not exists email text not null default '';

update public.profiles p
set email = coalesce(u.email, p.email, '')
from auth.users u
where u.id = p.id and (p.email is null or p.email = '');

-- 2) Helpers
create or replace function public.current_user_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function public.is_org_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

-- 3) Invites
create table if not exists public.organization_invites (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  email text not null,
  role text not null default 'employee' check (role in ('employee')),
  token text not null unique default encode(gen_random_bytes(24), 'hex'),
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'revoked')),
  invited_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  accepted_at timestamptz
);

create index if not exists organization_invites_org_id_idx
  on public.organization_invites (org_id);
create index if not exists organization_invites_token_idx
  on public.organization_invites (token);
create index if not exists organization_invites_email_idx
  on public.organization_invites (lower(email));

-- One pending invite per email per org
create unique index if not exists organization_invites_pending_email_org_uidx
  on public.organization_invites (org_id, lower(email))
  where status = 'pending';

alter table public.organization_invites enable row level security;

drop policy if exists invites_select_admin on public.organization_invites;
create policy invites_select_admin on public.organization_invites
  for select using (
    org_id = public.current_org_id() and public.is_org_admin()
  );

drop policy if exists invites_insert_admin on public.organization_invites;
create policy invites_insert_admin on public.organization_invites
  for insert with check (
    org_id = public.current_org_id()
    and public.is_org_admin()
    and role = 'employee'
  );

drop policy if exists invites_update_admin on public.organization_invites;
create policy invites_update_admin on public.organization_invites
  for update using (
    org_id = public.current_org_id() and public.is_org_admin()
  );

-- Public preview of a pending invite (by token) for the accept page.
create or replace function public.get_invite_preview(invite_token text)
returns table (
  token text,
  email text,
  organization_name text,
  status text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    i.token,
    i.email,
    o.name as organization_name,
    i.status
  from public.organization_invites i
  join public.organizations o on o.id = i.org_id
  where i.token = invite_token
  limit 1;
$$;

grant execute on function public.get_invite_preview(text) to anon, authenticated;

-- 4) Signup: invite → join org as employee; otherwise create workspace as admin
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
  invite_token text;
  invite_row public.organization_invites%rowtype;
begin
  display := coalesce(
    nullif(trim(new.raw_user_meta_data->>'display_name'), ''),
    split_part(new.email, '@', 1)
  );
  invite_token := nullif(trim(new.raw_user_meta_data->>'invite_token'), '');

  if invite_token is not null then
    select * into invite_row
    from public.organization_invites
    where token = invite_token
      and status = 'pending'
    for update;

    if not found then
      raise exception 'Invite is invalid or already used';
    end if;

    if lower(invite_row.email) <> lower(new.email) then
      raise exception 'Invite email does not match sign-up email';
    end if;

    insert into public.profiles (id, org_id, display_name, role, email)
    values (new.id, invite_row.org_id, display, 'employee', coalesce(new.email, ''));

    update public.organization_invites
    set status = 'accepted', accepted_at = now()
    where id = invite_row.id;

    return new;
  end if;

  org_name := coalesce(
    nullif(trim(new.raw_user_meta_data->>'organization_name'), ''),
    'My workspace'
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

  insert into public.profiles (id, org_id, display_name, role, email)
  values (new.id, new_org_id, display, 'admin', coalesce(new.email, ''));

  return new;
end;
$$;
