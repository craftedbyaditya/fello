import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the app does not install a pre-router desktop-only route gate', () {
    final source = File('lib/main.dart').readAsStringSync();

    // A MaterialApp.router builder is above the router. Calling GoRouter.of
    // from one made every narrow live viewport crash before sign-in rendered.
    expect(source, isNot(contains('WebDesktopOnlyGate')));
  });
}
