import '../entities/feedback_form.dart';
import '../entities/question.dart';

abstract class FormRepository {
  Future<List<FeedbackForm>> listForms(String orgId);
  Future<FeedbackForm?> getForm(String formId);
  Future<FeedbackForm?> getPublishedBySlug(String slug);

  Future<FeedbackForm> createForm({
    required String orgId,
    required String title,
    required String description,
  });

  Future<FeedbackForm> updateForm(FeedbackForm form);
  Future<FeedbackForm> publishForm(String formId);

  /// Turns the public link off (draft). Does not soft-delete.
  Future<FeedbackForm> unpublishForm(String formId);

  /// Soft-delete — survey stays in the list with Deleted status.
  Future<FeedbackForm> deleteForm(String formId);

  Future<Question> upsertQuestion(Question question);
  Future<void> deleteQuestion(String questionId);
  Future<void> reorderQuestions(String formId, List<String> questionIds);
}
