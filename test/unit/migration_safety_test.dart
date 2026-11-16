import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('obsolete RLS helper revoke is safe on a clean schema', () {
    final migration = File(
      'supabase/migrations/20260324194000_harden_rpc_grants_and_board_indexes.sql',
    ).readAsStringSync();

    expect(
      migration,
      contains("to_regprocedure('public.rls_auto_enable()') is not null"),
    );
    expect(
      migration.indexOf(
        'revoke all on function public.rls_auto_enable() from public, anon, authenticated;',
      ),
      greaterThan(
        migration.indexOf("if to_regprocedure('public.rls_auto_enable()')"),
      ),
    );
  });

  test('digest-using security-definer functions include pgcrypto schema', () {
    final migration = File(
      'supabase/migrations/20261115194000_fix_security_definer_extension_path.sql',
    ).readAsStringSync();

    expect(migration, contains('public.create_org_api_key(text)'));
    expect(migration, contains('public.resolve_org_api_key(text)'));
    expect(
      migration,
      contains(
        'public.submit_public_response(uuid, jsonb, jsonb, text, uuid, text)',
      ),
    );
    expect(migration, contains('set search_path = public, extensions;'));
  });

  test('free-launch feature switches are deny-by-default and audited', () {
    final migration = File(
      'supabase/migrations/20261116100000_global_feature_flags_free_launch.sql',
    ).readAsStringSync();

    expect(migration, contains("('feedback_submissions_enabled', true)"));
    expect(migration, contains("('task_board_enabled', false)"));
    expect(migration, contains("('reviews_api_enabled', false)"));
    expect(migration, contains('coalesce((select enabled'));
    expect(migration, contains('global_feature_flag_audit'));
    expect(migration, contains('platform operator required'));
  });
}
