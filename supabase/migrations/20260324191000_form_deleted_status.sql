-- Soft-delete surveys: keep rows in list with status = deleted.
-- Active surveys for plan limits exclude deleted.

alter table public.forms drop constraint if exists forms_status_check;
alter table public.forms
  add constraint forms_status_check
  check (status in ('draft', 'published', 'deleted'));

create or replace function public.org_survey_count(p_org_id uuid)
returns int
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::int
  from public.forms
  where org_id = p_org_id
    and status <> 'deleted';
$$;
