import 'package:uuid/uuid.dart';

import '../../domain/ai/feedback_ai_heuristic.dart';
import '../../domain/auth_permission_failure.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/entities/complaint_task.dart';
import '../../domain/entities/feedback_analysis.dart';
import '../../domain/entities/question.dart';
import '../../domain/entities/response.dart';
import '../../domain/repositories/workflow_repository.dart';
import 'mock_store.dart';

class MockWorkflowRepository implements WorkflowRepository {
  MockWorkflowRepository(this._store);

  final MockStore _store;
  static const _uuid = Uuid();
  static const _ai = FeedbackAiHeuristic();

  @override
  Future<FeedbackAnalysis?> getAnalysisForResponse(String responseId) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    for (final a in _store.analyses) {
      if (a.responseId == responseId) return a;
    }
    return null;
  }

  @override
  Future<Map<String, FeedbackAnalysis>> getAnalysesForResponses(
    List<String> responseIds,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final ids = responseIds.toSet();
    return {
      for (final a in _store.analyses)
        if (ids.contains(a.responseId)) a.responseId: a,
    };
  }

  @override
  Future<List<ComplaintTask>> listTasks({
    required String orgId,
    ComplaintTaskFilters filters = const ComplaintTaskFilters(),
    int limit = 200,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _assertOrg(orgId);
    final formResponseIds = filters.formId == null
        ? null
        : _store.responses
            .where((r) => r.formId == filters.formId)
            .map((r) => r.id)
            .toSet();
    final list = _store.complaintTasks.where((t) {
      if (t.orgId != orgId) return false;
      if (formResponseIds != null) {
        final rid = t.responseId;
        if (rid == null || !formResponseIds.contains(rid)) return false;
      }
      if (filters.status != null && t.status != filters.status) return false;
      if (filters.priority != null && t.priority != filters.priority) {
        return false;
      }
      if (filters.category != null &&
          filters.category!.isNotEmpty &&
          t.category != filters.category) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.take(limit).map(_withCommentCount).toList();
  }

  ComplaintTask _withCommentCount(ComplaintTask t) {
    final count =
        _store.taskComments.where((c) => c.taskId == t.id).length;
    return count == t.commentCount ? t : t.copyWith(commentCount: count);
  }

  @override
  Future<ComplaintTask?> getTask(String taskId) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    try {
      final task = _store.complaintTasks.firstWhere((t) => t.id == taskId);
      _assertOrg(task.orgId);
      return task;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ComplaintTask?> getTaskForResponse(String responseId) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    try {
      final task =
          _store.complaintTasks.firstWhere((t) => t.responseId == responseId);
      _assertOrg(task.orgId);
      return task;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ComplaintTask> updateTask({
    required String taskId,
    ComplaintTaskStatus? status,
    String? assignedTo,
    String? resolutionNotes,
    String? title,
    String? description,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final index = _store.complaintTasks.indexWhere((t) => t.id == taskId);
    if (index < 0) throw StateError('Task not found');
    final task = _store.complaintTasks[index];
    _assertOrg(task.orgId);
    final session = _store.currentSession;
    if (session == null) {
      throw const AuthPermissionFailure('Sign in required.');
    }
    if (session.organization.id != task.orgId) {
      throw const AuthPermissionFailure(
        'You cannot access another organisation’s data.',
      );
    }
    if (assignedTo != null) {
      final ok = _store.profiles.any(
        (p) => p.id == assignedTo && p.orgId == task.orgId,
      );
      if (!ok) {
        throw const AuthPermissionFailure(
          'Cannot assign tasks to another organisation.',
        );
      }
    }
    String? assigneeName = task.assigneeName;
    if (assignedTo != null) {
      for (final p in _store.profiles) {
        if (p.id == assignedTo) {
          assigneeName = p.displayName;
          break;
        }
      }
    }
    final trimmedTitle = title?.trim();
    if (trimmedTitle != null &&
        (trimmedTitle.isEmpty || trimmedTitle.length > 200)) {
      throw StateError('Title must be 1–200 characters.');
    }
    final trimmedDesc = description?.trim();
    if (trimmedDesc != null && trimmedDesc.length > 4000) {
      throw StateError('Description must be at most 4000 characters.');
    }
    final updated = task.copyWith(
      status: status,
      assignedTo: assignedTo ?? task.assignedTo,
      assigneeName: assigneeName,
      resolutionNotes: resolutionNotes ?? task.resolutionNotes,
      title: trimmedTitle,
      description: trimmedDesc,
      updatedAt: DateTime.now().toUtc(),
    );
    _store.complaintTasks[index] = updated;
    return _withCommentCount(updated);
  }

  @override
  Future<ComplaintTask> createManualTask({
    required String title,
    required String description,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final session = _store.currentSession;
    if (session == null) {
      throw const AuthPermissionFailure('Sign in required.');
    }
    final trimmed = title.trim();
    if (trimmed.isEmpty || trimmed.length > 200) {
      throw StateError('Title must be 1–200 characters.');
    }
    final desc = description.trim();
    if (desc.length > 4000) {
      throw StateError('Description must be at most 4000 characters.');
    }
    final now = DateTime.now().toUtc();
    final task = ComplaintTask(
      id: _uuid.v4(),
      orgId: session.organization.id,
      title: trimmed,
      description: desc,
      category: 'General',
      priority: ComplaintPriority.medium,
      status: ComplaintTaskStatus.open,
      createdAt: now,
      updatedAt: now,
      createdBy: session.profile.id,
      creatorName: session.profile.displayName,
      source: ComplaintTaskSource.manual,
    );
    _store.complaintTasks.add(task);
    return task;
  }

  @override
  Future<List<TaskComment>> listTaskComments(String taskId) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final task = await getTask(taskId);
    if (task == null) throw StateError('Task not found');
    final list = _store.taskComments.where((c) => c.taskId == taskId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  @override
  Future<TaskComment> addTaskComment({
    required String taskId,
    required String body,
    String? clientMutationId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final session = _store.currentSession;
    if (session == null) {
      throw const AuthPermissionFailure('Sign in required.');
    }
    final trimmed = body.trim();
    if (trimmed.isEmpty || trimmed.length > 2000) {
      throw StateError('Comment must be 1–2000 characters.');
    }
    final task = await getTask(taskId);
    if (task == null) throw StateError('Task not found');
    if (clientMutationId != null) {
      for (final c in _store.taskComments) {
        if (c.taskId == taskId &&
            c.authorId == session.profile.id &&
            c.id == 'mut-$clientMutationId') {
          return c;
        }
      }
    }
    final comment = TaskComment(
      id: clientMutationId == null
          ? _uuid.v4()
          : 'mut-$clientMutationId',
      orgId: task.orgId,
      taskId: taskId,
      authorId: session.profile.id,
      authorName: session.profile.displayName,
      body: trimmed,
      createdAt: DateTime.now().toUtc(),
    );
    _store.taskComments.add(comment);
    return comment;
  }

  @override
  Future<ComplaintInsights> getComplaintInsights(
    String orgId, {
    String? formId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _assertOrg(orgId);
    final formResponseIds = formId == null
        ? null
        : _store.responses
            .where((r) => r.formId == formId)
            .map((r) => r.id)
            .toSet();
    final tasks = _store.complaintTasks.where((t) {
      if (t.orgId != orgId) return false;
      if (formResponseIds != null && !formResponseIds.contains(t.responseId)) {
        return false;
      }
      return true;
    }).toList();
    final open = tasks
        .where(
          (t) =>
              t.status == ComplaintTaskStatus.open ||
              t.status == ComplaintTaskStatus.inProgress,
        )
        .length;
    final resolved = tasks
        .where(
          (t) =>
              t.status == ComplaintTaskStatus.resolved ||
              t.status == ComplaintTaskStatus.closed,
        )
        .length;
    final byCategory = <String, int>{};
    for (final t in tasks) {
      byCategory[t.category] = (byCategory[t.category] ?? 0) + 1;
    }
    final rising = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ComplaintInsights(
      openCount: open,
      resolvedCount: resolved,
      byCategory: byCategory,
      risingCategories: rising.take(3).map((e) => e.key).toList(),
    );
  }

  @override
  Future<List<AppNotification>> listNotifications({int limit = 30}) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final session = _store.currentSession;
    if (session == null) return [];
    final list = _store.notifications
        .where((n) => n.userId == session.profile.id)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (list.length <= limit) return list;
    return list.sublist(0, limit);
  }

  @override
  Future<int> unreadNotificationCount() async {
    final session = _store.currentSession;
    if (session == null) return 0;
    return _store.notifications
        .where((n) => n.userId == session.profile.id && n.isUnread)
        .length;
  }

  @override
  Future<void> markNotificationRead(String notificationId) async {
    final session = _store.currentSession;
    if (session == null) return;
    final i = _store.notifications.indexWhere((n) => n.id == notificationId);
    if (i < 0) return;
    final n = _store.notifications[i];
    if (n.userId != session.profile.id) {
      throw const AuthPermissionFailure('Not your notification.');
    }
    _store.notifications[i] = AppNotification(
      id: n.id,
      orgId: n.orgId,
      userId: n.userId,
      type: n.type,
      title: n.title,
      body: n.body,
      payload: n.payload,
      readAt: DateTime.now().toUtc(),
      createdAt: n.createdAt,
    );
  }

  @override
  Future<void> markAllNotificationsRead() async {
    final session = _store.currentSession;
    if (session == null) return;
    final now = DateTime.now().toUtc();
    for (var i = 0; i < _store.notifications.length; i++) {
      final n = _store.notifications[i];
      if (n.userId != session.profile.id || !n.isUnread) continue;
      _store.notifications[i] = AppNotification(
        id: n.id,
        orgId: n.orgId,
        userId: n.userId,
        type: n.type,
        title: n.title,
        body: n.body,
        payload: n.payload,
        readAt: now,
        createdAt: n.createdAt,
      );
    }
  }

  @override
  Future<void> processResponseLocally(String responseId) async {
    await Future<void>.delayed(const Duration(milliseconds: 40));
    if (_store.processedAiResponseIds.contains(responseId)) return;
    FeedbackResponse? response;
    for (final r in _store.responses) {
      if (r.id == responseId) {
        response = r;
        break;
      }
    }
    if (response == null) return;
    final form = _store.forms.firstWhere((f) => f.id == response!.formId);
    final texts = <String>[];
    double? rating;
    for (final a in response.answers) {
      Question? q;
      for (final qq in form.questions) {
        if (qq.id == a.questionId) {
          q = qq;
          break;
        }
      }
      if (q == null) continue;
      if (q.type == QuestionType.starRating && a.value is num) {
        rating = (a.value as num).toDouble();
      } else if ((q.type == QuestionType.shortText ||
              q.type == QuestionType.longText) &&
          a.value is String) {
        texts.add((a.value as String).trim());
      }
    }
    final text = texts.join(' ');
    final eligible = text.length >= 8 || (rating != null && rating <= 3);
    if (!eligible) {
      _store.processedAiResponseIds.add(responseId);
      return;
    }

    final result = _ai.analyze(
      responseId: responseId,
      orgId: form.orgId,
      text: text,
      rating: rating,
    );

    FeedbackAnalysis? existingAnalysis;
    for (final a in _store.analyses) {
      if (a.responseId == responseId) {
        existingAnalysis = a;
        break;
      }
    }
    if (existingAnalysis == null) {
      _store.analyses.add(result.analysis);
    }
    final analysis = existingAnalysis ?? result.analysis;
    final shouldCreate =
        existingAnalysis?.actionRecommended ?? result.shouldCreateTask;

    if (shouldCreate &&
        !_store.complaintTasks.any((t) => t.responseId == responseId)) {
      final admin = _store.profiles.firstWhere(
        (p) => p.orgId == form.orgId && p.isAdmin,
        orElse: () => _store.profiles.firstWhere((p) => p.orgId == form.orgId),
      );
      final now = DateTime.now().toUtc();
      final taskId = _uuid.v4();
      final task = ComplaintTask(
        id: taskId,
        orgId: form.orgId,
        responseId: responseId,
        analysisId: analysis.id,
        title: '${analysis.primaryCategory}: follow up',
        description: '${analysis.summary}\n\nCustomer: $text',
        category: analysis.primaryCategory,
        priority: ComplaintPriorityX.fromWire(analysis.urgency.wire),
        status: ComplaintTaskStatus.open,
        assignedTo: admin.id,
        assigneeName: admin.displayName,
        dueAt: now.add(const Duration(days: 3)),
        createdAt: now,
        updatedAt: now,
        createdBy: null,
        creatorName: null,
        source: ComplaintTaskSource.ai,
      );
      _store.complaintTasks.add(task);
      _store.notifications.add(
        AppNotification(
          id: _uuid.v4(),
          orgId: form.orgId,
          userId: admin.id,
          type: 'complaint_task',
          title: 'New follow-up on ${form.title}',
          body: task.title,
          payload: {
            'task_id': taskId,
            'response_id': responseId,
            'form_id': form.id,
            'category': task.category,
          },
          createdAt: now,
        ),
      );
    }
    _store.processedAiResponseIds.add(responseId);
  }

  void _assertOrg(String orgId) {
    final session = _store.currentSession;
    if (session != null && session.organization.id != orgId) {
      throw const AuthPermissionFailure(
        'You cannot access another organisation’s data.',
      );
    }
  }
}
