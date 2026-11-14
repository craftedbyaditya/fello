import 'entities/question.dart';

/// Shared client/server-shaped validation for public form answers.
class PublicAnswerValidator {
  const PublicAnswerValidator._();

  static String? validate({
    required List<Question> questions,
    required Map<String, dynamic> answers,
  }) {
    for (final key in answers.keys) {
      if (!questions.any((q) => q.id == key)) {
        return 'Unknown question in submission.';
      }
    }

    for (final q in questions) {
      final value = answers[q.id];
      final missing = value == null ||
          (value is String && value.trim().isEmpty) ||
          (value is List && value.isEmpty);
      if (q.required && missing) {
        return 'Please answer: ${q.label}';
      }
      if (missing) continue;

      switch (q.type) {
        case QuestionType.starRating:
          if (value is! num || value < 1 || value > 5) {
            return 'Star rating must be 1–5.';
          }
        case QuestionType.nps:
          if (value is! num || value < 0 || value > 10) {
            return 'NPS must be 0–10.';
          }
        case QuestionType.shortText:
        case QuestionType.longText:
          if (value is! String) return 'Text answer must be a string.';
        case QuestionType.yesNo:
          if (value is! bool && value is! String) {
            return 'Yes/No answer is invalid.';
          }
        case QuestionType.singleChoice:
          if (value is! String) return 'Choice must be a string.';
          if (q.options.isNotEmpty && !q.options.contains(value)) {
            return 'Choice is not a valid option.';
          }
        case QuestionType.multiChoice:
          if (value is! List) return 'Multi choice must be a list.';
      }
    }
    return null;
  }
}
