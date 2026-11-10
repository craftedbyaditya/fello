---
name: fello-bloc-feature
description: Implement a Fello feature vertical slice with BLoC, repositories, routes, and tests.
---

# Fello BLoC feature slice

## Order of work

1. Domain entity + repository method (if needed).
2. Mock repository behavior (+ seed if needed).
3. Supabase repository method (+ migration via fello-supabase-sync if schema changes).
4. Events / states / bloc.
5. Presentation UI with loading, empty, and error states.
6. Wire route in `app_router.dart` with auth guards if org-only.
7. Tests: bloc_test and/or unit tests.

## Conventions

- BLoCs talk only to repository interfaces from `get_it`.
- Do not import `supabase_flutter` or mock store from presentation.
- Public respondent routes stay under `/f/:slug` and never require auth.
- Prefer existing theme tokens in `FelloColors` / `FelloTheme`.

## Agents

- `.cursor/agents/feature-implementer.md`
- `.cursor/agents/test-writer.md`
