import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('anonymous published-form RLS never invokes current_org_id', () {
    final source = File(
      'supabase/migrations/20261117110000_fix_anon_published_form_rls.sql',
    ).readAsStringSync();

    final anonymousForms = source.substring(
      source.indexOf('create policy forms_select_published_anon'),
      source.indexOf('create policy forms_select_member_authenticated'),
    );
    final anonymousQuestions = source.substring(
      source.indexOf('create policy questions_select_published_anon'),
      source.indexOf('create policy questions_select_member_authenticated'),
    );

    expect(anonymousForms, contains('for select to anon'));
    expect(anonymousForms, isNot(contains('current_org_id')));
    expect(anonymousQuestions, contains('for select to anon'));
    expect(anonymousQuestions, isNot(contains('current_org_id')));
    expect(source, contains('forms_select_member_authenticated'));
    expect(source, contains('questions_select_member_authenticated'));
    expect(source, contains('responses_select_member_authenticated'));
    expect(source, contains('answers_select_member_authenticated'));
  });
}
