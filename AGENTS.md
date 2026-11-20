# Kaydo agent rules

Product: **Kaydo** — Flutter web-first feedback platform with Supabase.

## Architecture

- Feature folders under `lib/features/*` with BLoC + presentation.
- Domain entities + repository interfaces in `lib/domain`.
- Data: `lib/data/mock/*` and `lib/data/supabase/*` behind the same interfaces.
- Switch with `--dart-define=DATA_SOURCE=mock|supabase` (default `mock`).
- Navigation via `go_router` in `lib/core/router/app_router.dart`.

## When a requirement touches data

Follow `.cursor/skills/fello-supabase-sync/SKILL.md`:

1. Add an **additive** migration under `supabase/migrations/` (never rewrite applied migrations).
2. Update `supabase/seed.sql` if fixtures change.
3. Update domain entities/models.
4. Update **both** mock and supabase repository implementations.
5. Update dashboard aggregations / public form if they depend on the shape.
6. Add or adjust tests.

## When adding a UI feature

Follow `.cursor/skills/fello-bloc-feature/SKILL.md` and prefer the agent briefs in `.cursor/agents/`.

## Quality bar

- Production-grade Dart: null-safety, clear errors, loading/empty states.
- `flutter analyze` clean; bloc/unit tests for changed logic.
- Keep UX minimal: Kaydo brand, teal/charcoal theme, intentional motion.

## Routine developer operations

- Prefer `scripts/kaydo` for routine checks, builds, database-readiness checks,
  GitHub status, and draft PR preparation; do not manually repeat its scripted
  checks.
- Use its LM Studio integration only for optional local log summaries. Read the
  raw log when a summary is insufficient.
- Reserve agent reasoning for engineering decisions and investigation.
- A successful CI run is not proof that production is correct; require a
  separate, explicit production verification.
