-- Seed mirrors lib/data/mock/mock_seed.dart for local/demo parity.
-- Note: profiles require auth.users rows. Prefer mock mode for UI demos,
-- or create ada@harbor.coffee via Auth then map IDs below.

-- Demo organisation + published form (safe to run in empty projects for schema smoke tests)
insert into public.organizations (id, name, slug, created_at)
values (
  '11111111-1111-1111-1111-111111111111',
  'Harbor Coffee',
  'harbor-coffee',
  now() - interval '40 days'
)
on conflict (id) do nothing;

insert into public.forms (id, org_id, title, description, slug, status, created_at)
values (
  '22222222-2222-2222-2222-222222222222',
  '11111111-1111-1111-1111-111111111111',
  'Post-visit feedback',
  'A quick pulse check after your café visit.',
  'harbor-visit',
  'published',
  now() - interval '20 days'
)
on conflict (id) do nothing;

insert into public.questions (id, form_id, type, label, required, options, sort_order)
values
  ('33333333-3333-3333-3333-333333333301', '22222222-2222-2222-2222-222222222222', 'starRating', 'How was your visit?', true, '[]', 0),
  ('33333333-3333-3333-3333-333333333302', '22222222-2222-2222-2222-222222222222', 'nps', 'How likely are you to recommend us?', true, '[]', 1),
  ('33333333-3333-3333-3333-333333333303', '22222222-2222-2222-2222-222222222222', 'singleChoice', 'What brought you in today?', false, '["Coffee","Pastries","Meeting","Other"]', 2),
  ('33333333-3333-3333-3333-333333333304', '22222222-2222-2222-2222-222222222222', 'longText', 'Anything else we should know?', false, '[]', 3)
on conflict (id) do nothing;
