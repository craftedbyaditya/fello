import 'package:fello/domain/entities/business_type.dart';
import 'package:fello/domain/entities/question.dart';
import 'package:fello/domain/onboarding/starter_form_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generic starter has rating and free-text', () {
    final template = StarterFormTemplate.forBusinessType(null);
    expect(template.title, 'Customer experience');
    expect(template.questions, hasLength(2));
    expect(template.questions.first.type, QuestionType.starRating);
    expect(template.questions.last.type, QuestionType.longText);
  });

  test('cafe starter is personalised', () {
    final template =
        StarterFormTemplate.forBusinessType(BusinessType.restaurantCafe);
    expect(template.questions.length, greaterThanOrEqualTo(3));
    expect(
      template.questions.any((q) => q.label.contains('food')),
      isTrue,
    );
  });

  test('bank starter includes resolution question', () {
    final template =
        StarterFormTemplate.forBusinessType(BusinessType.bankFinancial);
    expect(
      template.questions.any((q) => q.label.toLowerCase().contains('resolved')),
      isTrue,
    );
  });
}
