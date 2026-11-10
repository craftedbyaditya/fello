# Fello

Fello helps organisations collect feedback through shareable forms (web link + QR). Customers submit without an account. Organisations get a dashboard with filters and charts.

## Stack

- Flutter (web-first, responsive)
- BLoC architecture + go_router
- Supabase schema/migrations (optional at runtime)
- Mock data layer by default for fast local demos

## Quick start (mock)

```bash
flutter pub get
flutter run -d chrome --web-port=3847
```

Demo organisation login:

- Email: `ada@harbor.coffee`
- Password: `fello123`

Public form preview (after publish): `/f/harbor-visit`

## Switch to Supabase

1. Apply SQL in `supabase/migrations/` (then optional `supabase/seed.sql`).
2. Run with defines:

```bash
flutter run -d chrome --web-port=3847 \
  --dart-define=DATA_SOURCE=supabase \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
  --dart-define=PUBLIC_BASE_URL=http://localhost:3847
```

Repositories share the same interfaces; only DI registration changes.

## Project layout

- `lib/domain` — entities + repository contracts
- `lib/data/mock` / `lib/data/supabase` — implementations
- `lib/features` — auth, onboarding, forms, dashboard, public_form
- `supabase/migrations` — source of truth for schema + RLS
- `.cursor/skills` + `.cursor/agents` — SQL sync and feature/test agents

## Agent / skill workflow

When a requirement changes persistence, follow `AGENTS.md` and `.cursor/skills/fello-supabase-sync/SKILL.md` so migrations, seed, mock, and supabase code stay aligned.

## Tests

```bash
flutter test
flutter analyze
```

## Local path

This repository is the Fello/Sayge project. Clone it to `/Users/adityarana/Code/Sayge` (or any path) on your machine.
