import '../entities/business_type.dart';
import '../entities/question.dart';

class StarterQuestionDraft {
  const StarterQuestionDraft({
    required this.type,
    required this.label,
    this.required = true,
  });

  final QuestionType type;
  final String label;
  final bool required;
}

class StarterFormTemplate {
  const StarterFormTemplate({
    required this.title,
    required this.description,
    required this.questions,
  });

  final String title;
  final String description;
  final List<StarterQuestionDraft> questions;

  /// Business-type-aware starter used when creating the first form from the
  /// dashboard CTA. Falls back to a generic customer-experience template.
  static StarterFormTemplate forBusinessType(BusinessType? type) {
    switch (type) {
      case BusinessType.restaurantCafe:
        return const StarterFormTemplate(
          title: 'Customer experience',
          description: 'Tell us how we did — it takes under a minute.',
          questions: [
            StarterQuestionDraft(
              type: QuestionType.starRating,
              label: 'How would you rate your experience?',
            ),
            StarterQuestionDraft(
              type: QuestionType.starRating,
              label: 'How was the food?',
              required: false,
            ),
            StarterQuestionDraft(
              type: QuestionType.starRating,
              label: 'How was the service?',
              required: false,
            ),
            StarterQuestionDraft(
              type: QuestionType.longText,
              label: 'What could we improve?',
              required: false,
            ),
          ],
        );
      case BusinessType.retail:
        return const StarterFormTemplate(
          title: 'Shopping experience',
          description: 'A quick pulse check after your visit.',
          questions: [
            StarterQuestionDraft(
              type: QuestionType.starRating,
              label: 'How would you rate your shopping experience?',
            ),
            StarterQuestionDraft(
              type: QuestionType.starRating,
              label: 'How helpful was our staff?',
              required: false,
            ),
            StarterQuestionDraft(
              type: QuestionType.yesNo,
              label: 'Did you find what you were looking for?',
            ),
            StarterQuestionDraft(
              type: QuestionType.longText,
              label: 'What could we improve?',
              required: false,
            ),
          ],
        );
      case BusinessType.automobile:
        return const StarterFormTemplate(
          title: 'Dealership experience',
          description: 'Help us improve your visit.',
          questions: [
            StarterQuestionDraft(
              type: QuestionType.starRating,
              label: 'How would you rate your dealership experience?',
            ),
            StarterQuestionDraft(
              type: QuestionType.starRating,
              label: 'How was the sales/service experience?',
              required: false,
            ),
            StarterQuestionDraft(
              type: QuestionType.starRating,
              label: 'How helpful was our staff?',
              required: false,
            ),
            StarterQuestionDraft(
              type: QuestionType.longText,
              label: 'What could we improve?',
              required: false,
            ),
          ],
        );
      case BusinessType.bankFinancial:
        return const StarterFormTemplate(
          title: 'Branch experience',
          description: 'Share feedback about your visit.',
          questions: [
            StarterQuestionDraft(
              type: QuestionType.starRating,
              label: 'How would you rate your branch experience?',
            ),
            StarterQuestionDraft(
              type: QuestionType.starRating,
              label: 'How satisfied are you with the service?',
              required: false,
            ),
            StarterQuestionDraft(
              type: QuestionType.yesNo,
              label: 'Was your query resolved?',
            ),
            StarterQuestionDraft(
              type: QuestionType.longText,
              label: 'What could we improve?',
              required: false,
            ),
          ],
        );
      case BusinessType.healthcare:
        return const StarterFormTemplate(
          title: 'Patient experience',
          description: 'Tell us how we can improve your visit.',
          questions: [
            StarterQuestionDraft(
              type: QuestionType.starRating,
              label: 'How would you rate your experience?',
            ),
            StarterQuestionDraft(
              type: QuestionType.starRating,
              label: 'How was the staff interaction?',
              required: false,
            ),
            StarterQuestionDraft(
              type: QuestionType.starRating,
              label: 'How was the waiting experience?',
              required: false,
            ),
            StarterQuestionDraft(
              type: QuestionType.longText,
              label: 'What could we improve?',
              required: false,
            ),
          ],
        );
      case BusinessType.hospitality:
      case BusinessType.professionalServices:
      case BusinessType.education:
      case BusinessType.other:
      case null:
        return const StarterFormTemplate(
          title: 'Customer experience',
          description: 'Tell us how we did — it takes under a minute.',
          questions: [
            StarterQuestionDraft(
              type: QuestionType.starRating,
              label: 'How would you rate your experience?',
            ),
            StarterQuestionDraft(
              type: QuestionType.longText,
              label: 'What could we improve?',
              required: false,
            ),
          ],
        );
    }
  }
}
