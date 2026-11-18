import 'package:flutter_test/flutter_test.dart';
import 'package:fello/features/dashboard/presentation/widgets/review_feed.dart';

void main() {
  test('anonymous responses use a stable short response ID', () {
    expect(
      responseDisplayId('a12b34c5-d67e-89f0-a123-b4567890cdef'),
      'A12B34C5',
    );
  });

  test('response timestamps use the 12-hour format', () {
    expect(
      readableResponseTimestamp(DateTime(2026, 11, 18, 13, 5)),
      'Nov 18, 2026, 1:05 PM',
    );
  });
}
