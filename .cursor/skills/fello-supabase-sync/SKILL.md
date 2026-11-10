---
name: fello-supabase-sync
description: Keep Fello SQL migrations, seed, domain models, and mock/supabase repositories in sync when persistence requirements change.
---

# Fello Supabase sync

Use this skill whenever a requirement changes schema, RLS, or how data is read/written.

## Rules

- Migrations are append-only. Create `supabase/migrations/YYYYMMDDHHMMSS_description.sql`.
- Prefer additive changes: new tables/columns (nullable or with defaults), new indexes, new policies.
- Do not drop columns/tables in the same change that app code still depends on.
- RLS must stay coherent: org members manage their data; anon can read published forms and insert responses/answers only for published forms.
- Mock fixtures in `lib/data/mock/mock_seed.dart` must stay conceptually aligned with `supabase/seed.sql`.

## Checklist (do all that apply)

- [ ] New/updated migration SQL
- [ ] Seed updated if demo data shape changes
- [ ] Domain entities updated
- [ ] Repository interfaces updated if method contracts change
- [ ] `Mock*Repository` updated
- [ ] `Supabase*Repository` updated
- [ ] BLoCs / dashboard stats / public submit still compile and behave
- [ ] Tests covering new validation or aggregation

## Agent brief

See `.cursor/agents/sql-migrator.md` for a reusable prompt when the task is primarily SQL + dependent file updates.
