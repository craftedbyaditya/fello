-- Public form reads must never evaluate current_org_id(): that helper is
-- intentionally unavailable to anon after the P0 hardening migration.
-- Keep anonymous access limited to already-published forms and their questions;
-- authenticated members retain tenant-scoped access to drafts and their own org.

drop policy if exists org_select_member on public.organizations;
drop policy if exists org_select_member_authenticated on public.organizations;
create policy org_select_member_authenticated on public.organizations
  for select to authenticated
  using (id = public.current_org_id());

drop policy if exists forms_select_member on public.forms;
drop policy if exists forms_select_published_anon on public.forms;
drop policy if exists forms_select_member_authenticated on public.forms;
create policy forms_select_published_anon on public.forms
  for select to anon
  using (status = 'published');
create policy forms_select_member_authenticated on public.forms
  for select to authenticated
  using (org_id = public.current_org_id() or status = 'published');

drop policy if exists questions_select on public.questions;
drop policy if exists questions_select_published_anon on public.questions;
drop policy if exists questions_select_member_authenticated on public.questions;
create policy questions_select_published_anon on public.questions
  for select to anon
  using (
    exists (
      select 1
      from public.forms f
      where f.id = questions.form_id
        and f.status = 'published'
    )
  );
create policy questions_select_member_authenticated on public.questions
  for select to authenticated
  using (
    exists (
      select 1
      from public.forms f
      where f.id = questions.form_id
        and (f.org_id = public.current_org_id() or f.status = 'published')
    )
  );

-- Response and answer records are never public.  Scope their member-read
-- policies to authenticated explicitly so an anonymous select is denied by
-- RLS (an empty result), without evaluating current_org_id().
drop policy if exists responses_select_member on public.responses;
drop policy if exists responses_select_member_authenticated on public.responses;
create policy responses_select_member_authenticated on public.responses
  for select to authenticated
  using (
    exists (
      select 1
      from public.forms f
      where f.id = responses.form_id
        and f.org_id = public.current_org_id()
    )
  );

drop policy if exists answers_select_member on public.answers;
drop policy if exists answers_select_member_authenticated on public.answers;
create policy answers_select_member_authenticated on public.answers
  for select to authenticated
  using (
    exists (
      select 1
      from public.responses r
      join public.forms f on f.id = r.form_id
      where r.id = answers.response_id
        and f.org_id = public.current_org_id()
    )
  );
