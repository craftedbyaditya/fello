-- 1) Role-aware RLS: employees may create/edit surveys; only admins may delete
--    forms or questions. Cross-org isolation remains via current_org_id().
-- 2) Hardened public submit: rate limit, dedupe, answer validation via RPC.

-- ---------------------------------------------------------------------------
-- Forms: delete = admin only (insert/update stay org-member)
-- ---------------------------------------------------------------------------
drop policy if exists forms_delete_member on public.forms;
drop policy if exists forms_delete_admin on public.forms;
create policy forms_delete_admin on public.forms
  for delete using (
    org_id = public.current_org_id()
    and public.is_org_admin()
  );

-- Questions: delete = admin only
drop policy if exists questions_delete_member on public.questions;
drop policy if exists questions_delete_admin on public.questions;
create policy questions_delete_admin on public.questions
  for delete using (
    public.is_org_admin()
    and exists (
      select 1 from public.forms f
      where f.id = form_id and f.org_id = public.current_org_id()
    )
  );

-- Tighten answers: question must belong to the response's form
drop policy if exists answers_insert_published on public.answers;
create policy answers_insert_published on public.answers
  for insert with check (
    exists (
      select 1
      from public.responses r
      join public.forms f on f.id = r.form_id
      join public.questions q on q.id = question_id and q.form_id = f.id
      where r.id = response_id
        and f.status = 'published'
    )
  );

-- ---------------------------------------------------------------------------
-- Public submit guards
-- ---------------------------------------------------------------------------
create table if not exists public.submission_rate_limits (
  client_key text not null,
  form_id uuid not null references public.forms (id) on delete cascade,
  window_started_at timestamptz not null default now(),
  hit_count int not null default 1,
  primary key (client_key, form_id)
);

create table if not exists public.submission_dedupe (
  submission_id uuid primary key,
  form_id uuid not null references public.forms (id) on delete cascade,
  created_at timestamptz not null default now()
);

create index if not exists submission_dedupe_form_id_idx
  on public.submission_dedupe (form_id);

alter table public.submission_rate_limits enable row level security;
alter table public.submission_dedupe enable row level security;
-- No direct client policies — only security definer RPC touches these.

create or replace function public.submit_public_response(
  p_form_id uuid,
  p_answers jsonb,
  p_metadata jsonb default '{}'::jsonb,
  p_client_key text default null,
  p_submission_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_form public.forms%rowtype;
  v_response_id uuid := gen_random_uuid();
  v_client text;
  v_submission uuid;
  v_window interval := interval '10 minutes';
  v_max_hits int := 20;
  v_q record;
  v_val jsonb;
  v_key text;
begin
  select * into v_form from public.forms where id = p_form_id;
  if not found or v_form.status <> 'published' then
    raise exception 'FORM_UNAVAILABLE: This feedback form is unavailable.';
  end if;

  v_client := nullif(trim(coalesce(p_client_key, '')), '');
  if v_client is null then
    v_client := 'anonymous';
  end if;
  if length(v_client) > 128 then
    raise exception 'INVALID_CLIENT: Invalid client key.';
  end if;

  v_submission := coalesce(p_submission_id, gen_random_uuid());

  -- Dedupe (idempotent replay)
  if exists(select 1 from public.submission_dedupe where submission_id = v_submission) then
    raise exception 'DUPLICATE_SUBMISSION: This response was already submitted.';
  end if;

  -- Rate limit per client + form
  insert into public.submission_rate_limits (client_key, form_id, window_started_at, hit_count)
  values (v_client, p_form_id, now(), 1)
  on conflict (client_key, form_id) do update
    set
      hit_count = case
        when public.submission_rate_limits.window_started_at <= now() - v_window then 1
        else public.submission_rate_limits.hit_count + 1
      end,
      window_started_at = case
        when public.submission_rate_limits.window_started_at <= now() - v_window then now()
        else public.submission_rate_limits.window_started_at
      end;

  if (
    select hit_count from public.submission_rate_limits
    where client_key = v_client and form_id = p_form_id
  ) > v_max_hits then
    raise exception 'RATE_LIMITED: Too many submissions. Please try again later.';
  end if;

  -- Validate answers against live questions
  if p_answers is null or jsonb_typeof(p_answers) <> 'object' then
    raise exception 'INVALID_ANSWERS: Answers must be an object.';
  end if;

  -- Reject unknown question ids
  for v_key in select jsonb_object_keys(p_answers) loop
    if not exists (
      select 1 from public.questions q
      where q.form_id = p_form_id and q.id::text = v_key
    ) then
      raise exception 'INVALID_ANSWERS: Unknown question in submission.';
    end if;
  end loop;

  for v_q in
    select * from public.questions where form_id = p_form_id
  loop
    v_val := p_answers -> v_q.id::text;
    if v_q.required then
      if v_val is null or v_val = 'null'::jsonb
         or v_val = '""'::jsonb
         or v_val = '[]'::jsonb then
        raise exception 'INVALID_ANSWERS: Missing required answer for "%".', v_q.label;
      end if;
    end if;

    if v_val is null or v_val = 'null'::jsonb then
      continue;
    end if;

    if v_q.type = 'starRating' then
      if jsonb_typeof(v_val) <> 'number'
         or (v_val::text)::numeric < 1
         or (v_val::text)::numeric > 5 then
        raise exception 'INVALID_ANSWERS: Star rating must be 1–5.';
      end if;
    elsif v_q.type = 'nps' then
      if jsonb_typeof(v_val) <> 'number'
         or (v_val::text)::numeric < 0
         or (v_val::text)::numeric > 10 then
        raise exception 'INVALID_ANSWERS: NPS must be 0–10.';
      end if;
    elsif v_q.type in ('shortText', 'longText') then
      if jsonb_typeof(v_val) <> 'string' then
        raise exception 'INVALID_ANSWERS: Text answer must be a string.';
      end if;
    elsif v_q.type = 'yesNo' then
      if jsonb_typeof(v_val) <> 'boolean'
         and v_val::text not in ('true', 'false', '"yes"', '"no"', '"Yes"', '"No"') then
        raise exception 'INVALID_ANSWERS: Yes/No answer is invalid.';
      end if;
    elsif v_q.type = 'singleChoice' then
      if jsonb_typeof(v_val) <> 'string' then
        raise exception 'INVALID_ANSWERS: Choice must be a string.';
      end if;
      if jsonb_array_length(v_q.options) > 0
         and not exists (
           select 1
           from jsonb_array_elements_text(v_q.options) opt
           where opt = trim(both '"' from v_val::text)
         ) then
        raise exception 'INVALID_ANSWERS: Choice is not a valid option.';
      end if;
    elsif v_q.type = 'multiChoice' then
      if jsonb_typeof(v_val) <> 'array' then
        raise exception 'INVALID_ANSWERS: Multi choice must be an array.';
      end if;
    end if;
  end loop;

  insert into public.responses (id, form_id, metadata)
  values (
    v_response_id,
    p_form_id,
    coalesce(p_metadata, '{}'::jsonb) || jsonb_build_object('client_key_hash', left(md5(v_client), 12))
  );

  insert into public.answers (response_id, question_id, value)
  select
    v_response_id,
    q.id,
    p_answers -> q.id::text
  from public.questions q
  where q.form_id = p_form_id
    and p_answers ? q.id::text
    and p_answers -> q.id::text is not null
    and p_answers -> q.id::text <> 'null'::jsonb;

  insert into public.submission_dedupe (submission_id, form_id)
  values (v_submission, p_form_id);

  return v_response_id;
end;
$$;

grant execute on function public.submit_public_response(uuid, jsonb, jsonb, text, uuid)
  to anon, authenticated;

-- Force public submits through the RPC (rate limit + validation).
drop policy if exists responses_insert_anon_published on public.responses;
drop policy if exists answers_insert_published on public.answers;
