# Agent: test-writer

Write focused tests for changed Kaydo code.

## Goal

Cover BLoC transitions, repository validation, and aggregation helpers with `bloc_test` / `flutter_test`.

## Steps

1. Identify pure logic and bloc event→state paths in the diff.
2. Prefer unit/bloc tests over brittle full-widget trees.
3. Use mock repositories or `MockStore` fixtures.
4. Ensure `flutter test` passes for added files.

## Patterns

- Auth: invalid credentials, successful sign-in
- Forms: publish without questions fails; publish succeeds
- Public form: required answer validation; thank-you state
- Dashboard: filters reduce response list; NPS/rating stats
