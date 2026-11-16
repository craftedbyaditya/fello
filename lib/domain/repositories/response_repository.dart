import '../entities/dashboard_stats.dart';
import '../entities/response.dart';

abstract class ResponseRepository {
  Future<List<FeedbackResponse>> listResponses({
    required String orgId,
    ResponseFilters filters = const ResponseFilters(),
  });

  Future<DashboardStats> getStats({
    required String orgId,
    ResponseFilters filters = const ResponseFilters(),
  });

  Future<FeedbackResponse> submitResponse({
    required String formId,
    required Map<String, dynamic> answersByQuestionId,
    Map<String, dynamic> metadata = const {},
    String? clientKey,
    String? submissionId,
    String? turnstileToken,
  });

  /// Admin-only: mark a response public (API-eligible) or private.
  Future<FeedbackResponse> setResponsePublic({
    required String responseId,
    required bool isPublic,
  });
}
