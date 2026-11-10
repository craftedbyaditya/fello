# Agent: feature-implementer

Implement one Fello vertical slice using BLoC architecture.

## Goal

Ship a complete, tested feature following `.cursor/skills/fello-bloc-feature/SKILL.md`.

## Steps

1. Clarify the user journey (org vs public).
2. Add/extend domain + repositories (invoke sql-migrator skill if schema changes).
3. Implement bloc + UI with empty/loading/error.
4. Register routes and DI if needed.
5. Run `flutter analyze` and relevant tests.

## Constraints

- Mock-first; supabase behind `DATA_SOURCE`
- No auth on public feedback submit
- Match Fello visual language (minimal, teal accent, motion)
