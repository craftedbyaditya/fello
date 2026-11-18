import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fello/core/theme/fello_metrics.dart';
import 'package:fello/shared/widgets/fello_text_field.dart';
import 'package:fello/shared/widgets/kaydo_search_field.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: 320, child: child)),
    ),
  );

  testWidgets('single-line shared inputs have the common control height', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FelloTextField(label: 'Workspace name'),
            const SizedBox(height: 16),
            KaydoSearchField(
              controller: TextEditingController(),
              hintText: 'Search surveys',
              onChanged: (_) {},
            ),
          ],
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(TextFormField)).height,
      FelloMetrics.textFieldHeight,
    );
    expect(
      tester
          .getSize(
            find.descendant(
              of: find.byType(KaydoSearchField),
              matching: find.byType(TextField),
            ),
          )
          .height,
      FelloMetrics.controlHeight,
    );
  });

  testWidgets('field validation text renders below the fixed input box', (
    tester,
  ) async {
    final key = GlobalKey<FormState>();
    await tester.pumpWidget(
      host(
        Form(
          key: key,
          child: const FelloTextField(label: 'Email', validator: _required),
        ),
      ),
    );

    expect(key.currentState!.validate(), isFalse);
    await tester.pump();

    expect(find.text('Required'), findsOneWidget);
    expect(
      tester.getSize(find.byType(TextFormField)).height,
      FelloMetrics.textFieldHeight,
    );
  });
}

String? _required(String? value) =>
    value == null || value.isEmpty ? 'Required' : null;
