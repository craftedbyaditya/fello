import 'package:flutter_test/flutter_test.dart';
import 'package:fello/domain/entities/question.dart';
import 'package:fello/features/dashboard/export/review_exporter.dart';
import 'package:fello/features/dashboard/presentation/widgets/review_feed.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds a valid compact PDF feedback report', () async {
    final bytes = await ReviewExporter.buildPdf(
      ReviewExportData(
        surveyTitle: 'Cafe feedback',
        createdAt: DateTime(2026, 11, 18),
        avgRating: 4.0,
        totalReviews: 1,
        reviews: [
          ReviewItem(
            id: 'response-1',
            formId: 'form-1',
            displayName: '',
            submittedAt: DateTime(2026, 11, 18, 10),
            location: '',
            stars: 4,
            answers: const [
              ReviewAnswer(
                questionId: 'question-1',
                label: 'How was the service?',
                type: QuestionType.singleChoice,
                value: 'Excellent',
              ),
              ReviewAnswer(
                questionId: 'question-2',
                label: 'What should we improve?',
                type: QuestionType.longText,
                value: 'Keep the seating area quieter.',
              ),
            ],
          ),
        ],
      ),
    );

    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
