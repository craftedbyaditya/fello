import '../entities/app_notification.dart';
import '../entities/complaint_task.dart';
import '../entities/feedback_analysis.dart';

abstract class WorkflowRepository {
  Future<FeedbackAnalysis?> getAnalysisForResponse(String responseId);

  Future<Map<String, FeedbackAnalysis>> getAnalysesForResponses(
    List<String> responseIds,
  );

  Future<List<ComplaintTask>> listTasks({
    required String orgId,
    ComplaintTaskFilters filters = const ComplaintTaskFilters(),
    int limit = 200,
  });

  Future<ComplaintTask?> getTask(String taskId);

  Future<ComplaintTask?> getTaskForResponse(String responseId);

  Future<ComplaintTask> updateTask({
    required String taskId,
    ComplaintTaskStatus? status,
    String? assignedTo,
    String? resolutionNotes,
    String? title,
    String? description,
  });

  Future<ComplaintTask> createManualTask({
    required String title,
    required String description,
  });

  Future<List<TaskComment>> listTaskComments(String taskId);

  Future<TaskComment> addTaskComment({
    required String taskId,
    required String body,
    String? clientMutationId,
  });

  Future<ComplaintInsights> getComplaintInsights(
    String orgId, {
    String? formId,
  });

  Future<List<AppNotification>> listNotifications({int limit = 30});

  Future<int> unreadNotificationCount();

  Future<void> markNotificationRead(String notificationId);

  Future<void> markAllNotificationsRead();

  /// Mock/dev helper: run local AI processing for a response.
  Future<void> processResponseLocally(String responseId);
}
