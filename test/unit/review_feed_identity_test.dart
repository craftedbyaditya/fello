import 'package:flutter_test/flutter_test.dart';
import 'package:fello/domain/entities/feedback_form.dart';
import 'package:fello/domain/entities/response.dart';
import 'package:fello/features/dashboard/presentation/widgets/review_feed.dart';

void main() {
  test('anonymous responses use a stable short response ID', () {
    expect(
      responseDisplayId('a12b34c5-d67e-89f0-a123-b4567890cdef'),
      'A12B34C5',
    );
  });

  test('visible response identifiers have a hash prefix', () {
    expect(
      visibleResponseId('a12b34c5-d67e-89f0-a123-b4567890cdef'),
      '#A12B34C5',
    );
  });

  test('response timestamps use the 12-hour format', () {
    expect(
      readableResponseTimestamp(DateTime(2026, 11, 18, 13, 5)),
      'Nov 18, 2026, 1:05 PM',
    );
  });

  test('reviews retain the immutable survey version that collected them', () {
    final form = FeedbackForm(
      id: 'form-1',
      orgId: 'org-1',
      title: 'Service feedback',
      description: '',
      slug: 'service',
      status: FormStatus.published,
      createdAt: DateTime(2026, 11, 18),
    );
    final summary = ReviewSummary.from(form, [
      FeedbackResponse(
        id: 'response-1',
        formId: form.id,
        formVersionId: 'version-2',
        formVersion: 2,
        submittedAt: DateTime(2026, 11, 18, 13),
      ),
    ]);

    expect(summary.reviews.single.formVersion, 2);
  });
}
