import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the app does not install a pre-router desktop-only route gate', () {
    final source = File('lib/main.dart').readAsStringSync();

    // A MaterialApp.router builder is above the router. Calling GoRouter.of
    // from one made every narrow live viewport crash before sign-in rendered.
    expect(source, isNot(contains('WebDesktopOnlyGate')));
  });

  test(
    'workspace navigation keeps a scrollable desktop rail and mobile drawer',
    () {
      final source = File(
        'lib/features/dashboard/presentation/shell_scaffold.dart',
      ).readAsStringSync();

      expect(source, contains('drawer: _MobileNavigationDrawer'));
      expect(source, contains('child: Scrollbar('));
      expect(source, contains('child: ListView('));
    },
  );

  test(
    'dashboard exposes existing forms before the first response arrives',
    () {
      final source = File(
        'lib/features/dashboard/presentation/dashboard_page.dart',
      ).readAsStringSync();

      expect(source, contains('] else if (state.forms.isNotEmpty)'));
      expect(source, contains('child: _FormTilesSection('));
    },
  );
}
