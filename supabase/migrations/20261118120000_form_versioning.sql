-- Published form versions are immutable. The editable forms/questions rows are
-- the working draft; public readers and submissions use the active snapshot.
-- This preserves the wording, type and options that existed when each response
-- was collected, even after a question is edited or removed from a later draft.

create table if not exists public.form_versions (
  id uuid primary key default gen_random_uuid(),
  form_id uuid not null references public.forms(id) on delete cascade,
  version integer not null check (version > 0),
  title text not null,
  description text not null default '',
  questions jsonb not null default '[]'::jsonb,
  published_at timestamptz not null default now(),
  unique (form_id, version)
);

alter table public.forms
  add column if not exists active_version_id uuid references public.form_versions(id) on delete restrict;
alter table public.responses
  add column if not exists form_version_id uuid references public.form_versions(id) on delete restrict;
alter table public.answers
  add column if not exists question_snapshot jsonb not null default '{}'::jsonb;

-- Question ids are useful for draft editing, but must not be able to erase a
-- historical answer. The immutable snapshot remains on answers.question_snapshot.
alter table public.answers alter column question_id drop not null;
alter table public.answers drop constraint if exists answers_question_id_fkey;
alter table public.answers
  add constraint answers_question_id_fkey
  foreign key (question_id) references public.questions(id) on delete set null;

create index if not exists form_versions_form_id_published_at_idx
  on public.form_versions(form_id, published_at desc);
create index if not exists responses_form_version_id_idx
  on public.responses(form_version_id);

-- One best-effort baseline is created for already-live forms. Historic
-- responses predate versioning, so their snapshot reflects the form definition
-- available at migration time; future responses are exact immutable snapshots.
insert into public.form_versions (form_id, version, title, description, questions)
select
  f.id,
  1,
  f.title,
  f.description,
  coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'id', q.id,
          'type', q.type,
          'label', q.label,
          'required', q.required,
          'options', q.options,
          'sort_order', q.sort_order
        ) order by q.sort_order
      )
      from public.questions q
      where q.form_id = f.id
    ),
    '[]'::jsonb
  )
from public.forms f
where f.status = 'published'
  and not exists (
    select 1 from public.form_versions fv where fv.form_id = f.id
  );

update public.forms f
set active_version_id = fv.id
from public.form_versions fv
where fv.form_id = f.id
  and f.status = 'published'
  and f.active_version_id is null
  and fv.version = (
    select max(v.version) from public.form_versions v where v.form_id = f.id
  );

update public.responses r
set form_version_id = f.active_version_id
from public.forms f
where f.id = r.form_id
  and r.form_version_id is null;

update public.answers a
set question_snapshot = jsonb_build_object(
  'id', q.id,
  'type', q.type,
  'label', q.label,
  'required', q.required,
  'options', q.options,
  'sort_order', q.sort_order
)
from public.questions q
where q.id = a.question_id
  and a.question_snapshot = '{}'::jsonb;

alter table public.form_versions enable row level security;
grant select on public.form_versions to anon, authenticated;

drop policy if exists form_versions_select_published_anon on public.form_versions;
create policy form_versions_select_published_anon on public.form_versions
  for select to anon
  using (
    exists (
      select 1 from public.forms f
      where f.id = form_versions.form_id
        and f.status = 'published'
        and f.active_version_id = form_versions.id
    )
  );

drop policy if exists form_versions_select_member_authenticated on public.form_versions;
create policy form_versions_select_member_authenticated on public.form_versions
  for select to authenticated
  using (
    exists (
      select 1 from public.forms f
      where f.id = form_versions.form_id
        and (
          f.org_id = public.current_org_id()
          or (f.status = 'published' and f.active_version_id = form_versions.id)
        )
    )
  );

-- Public reads move to the active version snapshot. This prevents an in-progress
-- draft edit from leaking through the public questions endpoint.
drop policy if exists questions_select_published_anon on public.questions;
drop policy if exists questions_select_member_authenticated on public.questions;
create policy questions_select_member_authenticated on public.questions
  for select to authenticated
  using (
    exists (
      select 1 from public.forms f
      where f.id = questions.form_id
        and f.org_id = public.current_org_id()
    )
  );

-- Only this function can promote the current editable draft to a live version.
create or replace function public.publish_form_version(p_form_id uuid)
returns public.forms
language plpgsql
security definer
set search_path = public
as $$
declare
  v_form public.forms%rowtype;
  v_version_id uuid;
  v_questions jsonb;
  v_next_version integer;
begin
  if auth.role() <> 'authenticated' then
    raise exception 'FORBIDDEN';
  end if;

  select * into v_form
  from public.forms
  where id = p_form_id and org_id = public.current_org_id()
  for update;
  if not found then
    raise exception 'FORM_NOT_FOUND';
  end if;
  if v_form.status = 'deleted' then
    raise exception 'FORM_UNAVAILABLE';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', q.id,
        'type', q.type,
        'label', q.label,
        'required', q.required,
        'options', q.options,
        'sort_order', q.sort_order
      ) order by q.sort_order
    ),
    '[]'::jsonb
  ) into v_questions
  from public.questions q
  where q.form_id = p_form_id;
  if jsonb_array_length(v_questions) = 0 then
    raise exception 'FORM_REQUIRES_QUESTION';
  end if;

  select coalesce(max(version), 0) + 1 into v_next_version
  from public.form_versions
  where form_id = p_form_id;

  insert into public.form_versions (form_id, version, title, description, questions)
  values (p_form_id, v_next_version, v_form.title, v_form.description, v_questions)
  returning id into v_version_id;

  perform set_config('kaydo.publish_form_version', 'on', true);
  update public.forms
  set status = 'published', active_version_id = v_version_id
  where id = p_form_id;

  return (select f from public.forms f where f.id = p_form_id);
end;
$$;

revoke all on function public.publish_form_version(uuid) from public, anon;
grant execute on function public.publish_form_version(uuid) to authenticated;

-- A normal client may save draft fields, but cannot fabricate an active version
-- or transition a form to published without an immutable snapshot.
create or replace function public.guard_form_publication()
returns trigger
language plpgsql
as $$
begin
  if new.active_version_id is distinct from old.active_version_id
     or (new.status = 'published' and old.status is distinct from 'published') then
    if current_setting('kaydo.publish_form_version', true) is distinct from 'on' then
      raise exception 'PUBLISH_VIA_VERSION_REQUIRED';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_form_publication on public.forms;
create trigger trg_guard_form_publication
  before update of status, active_version_id on public.forms
  for each row execute function public.guard_form_publication();

-- The submission RPC validates and snapshots the active published version,
-- never the mutable draft questions table.
create or replace function public.submit_public_response(
  p_form_id uuid, p_answers jsonb, p_metadata jsonb default '{}'::jsonb,
  p_client_key text default null, p_submission_id uuid default null, p_source_ip text default null
) returns uuid language plpgsql security definer set search_path = public, extensions as $$
declare
  v_form public.forms%rowtype;
  v_version public.form_versions%rowtype;
  v_response_id uuid := gen_random_uuid(); v_submission uuid;
  v_client text; v_ip_hash text; v_q record; v_val jsonb; v_key text;
  v_form_hits int; v_client_hits int;
begin
  if auth.role() <> 'service_role' and current_user not in ('postgres','supabase_admin') then raise exception 'FORBIDDEN'; end if;
  if pg_column_size(coalesce(p_answers, '{}'::jsonb)) > 65536 or pg_column_size(coalesce(p_metadata, '{}'::jsonb)) > 8192 then raise exception 'INVALID_SUBMISSION'; end if;
  select * into v_form from public.forms where id = p_form_id;
  if not found or v_form.status <> 'published' or v_form.active_version_id is null then raise exception 'FORM_UNAVAILABLE'; end if;
  select * into v_version from public.form_versions where id = v_form.active_version_id;
  if not found then raise exception 'FORM_UNAVAILABLE'; end if;
  if p_answers is null or jsonb_typeof(p_answers) <> 'object' or (select count(*) from jsonb_object_keys(p_answers)) > 100 then raise exception 'INVALID_ANSWERS'; end if;
  v_submission := coalesce(p_submission_id, gen_random_uuid());
  if exists(select 1 from public.submission_dedupe where submission_id=v_submission) then raise exception 'DUPLICATE_SUBMISSION'; end if;
  v_ip_hash := encode(digest(coalesce(nullif(trim(p_source_ip), ''), 'unavailable'), 'sha256'), 'hex');
  insert into public.form_submission_rate_limits(form_id, window_started_at, hit_count) values(p_form_id,now(),1)
  on conflict(form_id) do update set hit_count=case when form_submission_rate_limits.window_started_at <= now()-interval '10 minutes' then 1 else form_submission_rate_limits.hit_count+1 end, window_started_at=case when form_submission_rate_limits.window_started_at <= now()-interval '10 minutes' then now() else form_submission_rate_limits.window_started_at end returning hit_count into v_form_hits;
  if v_form_hits > 200 then raise exception 'RATE_LIMITED'; end if;
  insert into public.submission_rate_limits(client_key,form_id,source_ip_hash,window_started_at,hit_count) values(v_ip_hash,p_form_id,v_ip_hash,now(),1)
  on conflict(client_key,form_id) do update set hit_count=case when submission_rate_limits.window_started_at <= now()-interval '10 minutes' then 1 else submission_rate_limits.hit_count+1 end, window_started_at=case when submission_rate_limits.window_started_at <= now()-interval '10 minutes' then now() else submission_rate_limits.window_started_at end returning hit_count into v_client_hits;
  if v_client_hits > 20 then raise exception 'RATE_LIMITED'; end if;
  for v_key in select jsonb_object_keys(p_answers) loop
    if not exists(select 1 from jsonb_to_recordset(v_version.questions) as q(id uuid) where q.id::text=v_key) then raise exception 'INVALID_ANSWERS'; end if;
  end loop;
  for v_q in select * from jsonb_to_recordset(v_version.questions) as q(id uuid, type text, label text, required boolean, options jsonb, sort_order int) loop
    v_val:=p_answers->v_q.id::text;
    if v_q.required and (v_val is null or v_val='null'::jsonb or v_val='""'::jsonb or v_val='[]'::jsonb) then raise exception 'INVALID_ANSWERS'; end if;
    if v_val is null or v_val='null'::jsonb then continue; end if;
    if v_q.type in ('shortText','longText') and (jsonb_typeof(v_val)<>'string' or length(v_val #>> '{}') > case when v_q.type='shortText' then 1000 else 10000 end) then raise exception 'INVALID_ANSWERS'; end if;
    if v_q.type='starRating' and (jsonb_typeof(v_val)<>'number' or (v_val::text)::numeric<1 or (v_val::text)::numeric>5) then raise exception 'INVALID_ANSWERS'; end if;
    if v_q.type='nps' and (jsonb_typeof(v_val)<>'number' or (v_val::text)::numeric<0 or (v_val::text)::numeric>10) then raise exception 'INVALID_ANSWERS'; end if;
  end loop;
  insert into public.responses(id,form_id,form_version_id,metadata) values(v_response_id,p_form_id,v_version.id,jsonb_build_object('source_ip_hash',left(v_ip_hash,24)));
  insert into public.answers(response_id,question_id,question_snapshot,value)
  select v_response_id,q.id,jsonb_build_object('id',q.id,'type',q.type,'label',q.label,'required',q.required,'options',q.options,'sort_order',q.sort_order),p_answers->q.id::text
  from jsonb_to_recordset(v_version.questions) as q(id uuid, type text, label text, required boolean, options jsonb, sort_order int)
  where p_answers?q.id::text and p_answers->q.id::text is not null and p_answers->q.id::text<>'null'::jsonb;
  insert into public.submission_dedupe(submission_id,form_id) values(v_submission,p_form_id);
  return v_response_id;
end;
$$;

revoke all on function public.submit_public_response(uuid,jsonb,jsonb,text,uuid,text) from public,anon,authenticated;
grant execute on function public.submit_public_response(uuid,jsonb,jsonb,text,uuid,text) to service_role;
