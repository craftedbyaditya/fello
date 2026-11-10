-- Fello initial schema
-- Additive, RLS-first. Org members manage forms; anon can read published forms and insert responses.

create extension if not exists "pgcrypto";

create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  org_id uuid not null references public.organizations (id) on delete cascade,
  display_name text not null default '',
  role text not null default 'admin' check (role in ('admin', 'member')),
  created_at timestamptz not null default now()
);

create table if not exists public.forms (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  title text not null,
  description text not null default '',
  slug text not null unique,
  status text not null default 'draft' check (status in ('draft', 'published')),
  created_at timestamptz not null default now()
);

create table if not exists public.questions (
  id uuid primary key default gen_random_uuid(),
  form_id uuid not null references public.forms (id) on delete cascade,
  type text not null check (
    type in (
      'starRating',
      'nps',
      'shortText',
      'longText',
      'yesNo',
      'singleChoice',
      'multiChoice'
    )
  ),
  label text not null,
  required boolean not null default true,
  options jsonb not null default '[]'::jsonb,
  sort_order int not null default 0
);

create table if not exists public.responses (
  id uuid primary key default gen_random_uuid(),
  form_id uuid not null references public.forms (id) on delete cascade,
  submitted_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

create table if not exists public.answers (
  id uuid primary key default gen_random_uuid(),
  response_id uuid not null references public.responses (id) on delete cascade,
  question_id uuid not null references public.questions (id) on delete cascade,
  value jsonb not null
);

create index if not exists forms_org_id_idx on public.forms (org_id);
create index if not exists questions_form_id_idx on public.questions (form_id);
create index if not exists responses_form_id_idx on public.responses (form_id);
create index if not exists answers_response_id_idx on public.answers (response_id);

-- Helper: current user's org
create or replace function public.current_org_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select org_id from public.profiles where id = auth.uid();
$$;

-- On signup: create org + profile from user metadata
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
  org_name := coalesce(new.raw_user_meta_data->>'organization_name', 'My organisation');
  display := coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1));
  org_slug := lower(regexp_replace(org_name, '[^a-zA-Z0-9]+', '-', 'g'));
  org_slug := trim(both '-' from org_slug);
  if org_slug = '' then
    org_slug := substr(new.id::text, 1, 8);
  end if;
  -- ensure unique slug
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

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

alter table public.organizations enable row level security;
alter table public.profiles enable row level security;
alter table public.forms enable row level security;
alter table public.questions enable row level security;
alter table public.responses enable row level security;
alter table public.answers enable row level security;

-- Organizations
create policy org_select_member on public.organizations
  for select using (id = public.current_org_id());
create policy org_update_member on public.organizations
  for update using (id = public.current_org_id());

-- Profiles
create policy profiles_select_self_org on public.profiles
  for select using (org_id = public.current_org_id());
create policy profiles_update_self on public.profiles
  for update using (id = auth.uid());

-- Forms: members CRUD; anon can read published
create policy forms_select_member on public.forms
  for select using (
    org_id = public.current_org_id()
    or status = 'published'
  );
create policy forms_insert_member on public.forms
  for insert with check (org_id = public.current_org_id());
create policy forms_update_member on public.forms
  for update using (org_id = public.current_org_id());
create policy forms_delete_member on public.forms
  for delete using (org_id = public.current_org_id());

-- Questions: members CRUD; anon read for published forms
create policy questions_select on public.questions
  for select using (
    exists (
      select 1 from public.forms f
      where f.id = form_id
        and (f.org_id = public.current_org_id() or f.status = 'published')
    )
  );
create policy questions_insert_member on public.questions
  for insert with check (
    exists (
      select 1 from public.forms f
      where f.id = form_id and f.org_id = public.current_org_id()
    )
  );
create policy questions_update_member on public.questions
  for update using (
    exists (
      select 1 from public.forms f
      where f.id = form_id and f.org_id = public.current_org_id()
    )
  );
create policy questions_delete_member on public.questions
  for delete using (
    exists (
      select 1 from public.forms f
      where f.id = form_id and f.org_id = public.current_org_id()
    )
  );

-- Responses: members read; anon insert only for published forms
create policy responses_select_member on public.responses
  for select using (
    exists (
      select 1 from public.forms f
      where f.id = form_id and f.org_id = public.current_org_id()
    )
  );
create policy responses_insert_anon_published on public.responses
  for insert with check (
    exists (
      select 1 from public.forms f
      where f.id = form_id and f.status = 'published'
    )
  );

-- Answers: members read; insert when parent response form is published
create policy answers_select_member on public.answers
  for select using (
    exists (
      select 1
      from public.responses r
      join public.forms f on f.id = r.form_id
      where r.id = response_id and f.org_id = public.current_org_id()
    )
  );
create policy answers_insert_published on public.answers
  for insert with check (
    exists (
      select 1
      from public.responses r
      join public.forms f on f.id = r.form_id
      where r.id = response_id and f.status = 'published'
    )
  );
