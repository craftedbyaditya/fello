import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/auth_permission_failure.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/entities/complaint_task.dart';
import '../../domain/entities/feedback_analysis.dart';
import '../../domain/repositories/workflow_repository.dart';

class SupabaseWorkflowRepository implements WorkflowRepository {
  SupabaseWorkflowRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<FeedbackAnalysis?> getAnalysisForResponse(String responseId) async {
    final row = await _client
        .from('feedback_analysis')
        .select()
        .eq('response_id', responseId)
        .maybeSingle();
    if (row == null) return null;
    return _analysisFromRow(row);
  }

  @override
  Future<Map<String, FeedbackAnalysis>> getAnalysesForResponses(
    List<String> responseIds,
  ) async {
    if (responseIds.isEmpty) return {};
    final rows = await _client
        .from('feedback_analysis')
        .select()
        .inFilter('response_id', responseIds);
    final map = <String, FeedbackAnalysis>{};
    for (final row in rows as List) {
      final a = _analysisFromRow(Map<String, dynamic>.from(row as Map));
      map[a.responseId] = a;
    }
    return map;
  }

  static const _taskSelect =
      '*, profiles:assigned_to(display_name), creator:created_by(display_name), task_comments(count)';

  @override
  Future<List<ComplaintTask>> listTasks({
    required String orgId,
    ComplaintTaskFilters filters = const ComplaintTaskFilters(),
    int limit = 200,
  }) async {
    final select = filters.formId == null
        ? _taskSelect
        : '$_taskSelect, responses!inner(form_id)';

    var query = _client
        .from('complaint_tasks')
        .select(select)
        .eq('org_id', orgId);

    if (filters.formId != null) {
      query = query.eq('responses.form_id', filters.formId!);
    }
    if (filters.status != null) {
      query = query.eq('status', filters.status!.wire);
    }
    if (filters.priority != null) {
      query = query.eq('priority', filters.priority!.wire);
    }
    if (filters.category != null && filters.category!.isNotEmpty) {
      query = query.eq('category', filters.category!);
    }

    final rows = await query
        .order('created_at', ascending: false)
        .limit(limit.clamp(1, 500));
    return (rows as List)
        .map((r) => _taskFromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  @override
  Future<ComplaintTask?> getTask(String taskId) async {
    final row = await _client
        .from('complaint_tasks')
        .select(_taskSelect)
        .eq('id', taskId)
        .maybeSingle();
    if (row == null) return null;
    return _taskFromRow(Map<String, dynamic>.from(row));
  }

  @override
  Future<ComplaintTask?> getTaskForResponse(String responseId) async {
    final row = await _client
        .from('complaint_tasks')
        .select(_taskSelect)
        .eq('response_id', responseId)
        .maybeSingle();
    if (row == null) return null;
    return _taskFromRow(Map<String, dynamic>.from(row));
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
    try {
      if (title != null || description != null || status != null) {
        await _client.rpc(
          'update_board_task',
          params: {
            'p_task_id': taskId,
            'p_title': title,
            'p_description': description,
            'p_status': status?.wire,
          },
        );
        // Still patch assignee/notes via table update when needed.
        if (assignedTo != null || resolutionNotes != null) {
          return await updateTask(
            taskId: taskId,
            assignedTo: assignedTo,
            resolutionNotes: resolutionNotes,
          );
        }
        // Re-select with joins (RPC returns a bare row).
        final refreshed = await getTask(taskId);
        if (refreshed == null) {
          throw AuthPermissionFailure('Task not found after update.');
        }
        return refreshed;
      }

      final patch = <String, dynamic>{
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (assignedTo != null) patch['assigned_to'] = assignedTo;
      if (resolutionNotes != null) patch['resolution_notes'] = resolutionNotes;

      final row = await _client
          .from('complaint_tasks')
          .update(patch)
          .eq('id', taskId)
          .select(_taskSelect)
          .single();
      return _taskFromRow(Map<String, dynamic>.from(row));
    } on PostgrestException catch (e) {
      throw AuthPermissionFailure(e.message);
    }
  }

  @override
  Future<ComplaintTask> createManualTask({
    required String title,
    required String description,
  }) async {
    try {
      final row = await _client.rpc(
        'create_manual_board_task',
        params: {
          'p_title': title,
          'p_description': description,
        },
      );
      final created = Map<String, dynamic>.from(row as Map);
      final id = created['id'] as String?;
      if (id != null) {
        final refreshed = await getTask(id);
        if (refreshed != null) return refreshed;
      }
      return _taskFromRow(created);
    } on PostgrestException catch (e) {
      throw AuthPermissionFailure(e.message);
    }
  }

  @override
  Future<List<TaskComment>> listTaskComments(String taskId) async {
    final rows = await _client
        .from('task_comments')
        .select('*, profiles:author_id(display_name)')
        .eq('task_id', taskId)
        .order('created_at', ascending: true);
    return (rows as List)
        .map((r) => _commentFromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  @override
  Future<TaskComment> addTaskComment({
    required String taskId,
    required String body,
    String? clientMutationId,
  }) async {
    try {
      final row = await _client.rpc(
        'add_task_comment',
        params: {
          'p_task_id': taskId,
          'p_body': body,
          'p_client_mutation_id': clientMutationId,
        },
      );
      final map = Map<String, dynamic>.from(row as Map);
      // RPC returns bare row; resolve author name from session/client if needed.
      final profile = await _client
          .from('profiles')
          .select('display_name')
          .eq('id', map['author_id'] as String)
          .maybeSingle();
      map['profiles'] = profile;
      return _commentFromRow(map);
    } on PostgrestException catch (e) {
      throw AuthPermissionFailure(e.message);
    }
  }

  @override
  Future<ComplaintInsights> getComplaintInsights(
    String orgId, {
    String? formId,
  }) async {
    final select = formId == null
        ? 'status, category, created_at'
        : 'status, category, created_at, responses!inner(form_id)';
    var query =
        _client.from('complaint_tasks').select(select).eq('org_id', orgId);
    if (formId != null) {
      query = query.eq('responses.form_id', formId);
    }
    final rows = await query;

    var open = 0;
    var resolved = 0;
    final byCategory = <String, int>{};
    final recent = <String, int>{};
    final older = <String, int>{};
    final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 14));

    for (final raw in rows as List) {
      final row = Map<String, dynamic>.from(raw as Map);
      final status = row['status'] as String? ?? 'open';
      final category = (row['category'] as String?) ?? 'General';
      final created = DateTime.tryParse(row['created_at'] as String? ?? '');
      if (status == 'open' || status == 'in_progress') {
        open++;
      } else {
        resolved++;
      }
      byCategory[category] = (byCategory[category] ?? 0) + 1;
      if (created != null && created.isAfter(cutoff)) {
        recent[category] = (recent[category] ?? 0) + 1;
      } else {
        older[category] = (older[category] ?? 0) + 1;
      }
    }

    final rising = recent.entries
        .where((e) => e.value > (older[e.key] ?? 0))
        .toList()
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
    final rows = await _client
        .from('notification_events')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((r) => _notificationFromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  @override
  Future<int> unreadNotificationCount() async {
    final rows = await _client
        .from('notification_events')
        .select('id')
        .isFilter('read_at', null);
    return (rows as List).length;
  }

  @override
  Future<void> markNotificationRead(String notificationId) async {
    await _client.from('notification_events').update({
      'read_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', notificationId);
  }

  @override
  Future<void> markAllNotificationsRead() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _client
        .from('notification_events')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', uid)
        .isFilter('read_at', null);
  }

  @override
  Future<void> processResponseLocally(String responseId) async {
    // Queue processing is scheduler-only. Client code must never invoke the
    // service worker because it can claim jobs across organizations.
    return;
  }

  FeedbackAnalysis _analysisFromRow(Map<String, dynamic> row) {
    return FeedbackAnalysis(
      id: row['id'] as String,
      orgId: row['org_id'] as String,
      responseId: row['response_id'] as String,
      sentiment: FeedbackSentimentX.fromWire(row['sentiment'] as String?),
      primaryCategory: (row['primary_category'] as String?) ?? 'General',
      categories: (row['categories'] as List?)
              ?.map((e) => '$e')
              .toList() ??
          const [],
      positiveAspects: (row['positive_aspects'] as List?)
              ?.map((e) => '$e')
              .toList() ??
          const [],
      urgency: FeedbackUrgencyX.fromWire(row['urgency'] as String?),
      summary: (row['summary'] as String?) ?? '',
      actionRecommended: row['action_recommended'] as bool? ?? false,
      confidence: (row['confidence'] as num?)?.toDouble() ?? 0,
      model: row['model'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  ComplaintTask _taskFromRow(Map<String, dynamic> row) {
    final profile = row['profiles'];
    String? name;
    if (profile is Map) {
      name = profile['display_name'] as String?;
    }
    final creator = row['creator'];
    String? creatorName;
    if (creator is Map) {
      creatorName = creator['display_name'] as String?;
    }
    var commentCount = 0;
    final comments = row['task_comments'];
    if (comments is List && comments.isNotEmpty) {
      final first = comments.first;
      if (first is Map && first['count'] != null) {
        commentCount = (first['count'] as num).toInt();
      } else {
        commentCount = comments.length;
      }
    }
    return ComplaintTask(
      id: row['id'] as String,
      orgId: row['org_id'] as String,
      responseId: row['response_id'] as String?,
      analysisId: row['analysis_id'] as String?,
      title: row['title'] as String,
      description: (row['description'] as String?) ?? '',
      category: (row['category'] as String?) ?? 'General',
      priority: ComplaintPriorityX.fromWire(row['priority'] as String?),
      status: ComplaintTaskStatusX.fromWire(row['status'] as String?),
      assignedTo: row['assigned_to'] as String?,
      assigneeName: name,
      dueAt: row['due_at'] != null
          ? DateTime.tryParse(row['due_at'] as String)
          : null,
      resolutionNotes: (row['resolution_notes'] as String?) ?? '',
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      createdBy: row['created_by'] as String?,
      creatorName: creatorName,
      source: ComplaintTaskSourceX.fromWire(row['source'] as String?),
      commentCount: commentCount,
    );
  }

  TaskComment _commentFromRow(Map<String, dynamic> row) {
    final profile = row['profiles'];
    String authorName = 'Teammate';
    if (profile is Map) {
      authorName = (profile['display_name'] as String?) ?? authorName;
    }
    return TaskComment(
      id: row['id'] as String,
      orgId: row['org_id'] as String,
      taskId: row['task_id'] as String,
      authorId: row['author_id'] as String,
      authorName: authorName,
      body: row['body'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  AppNotification _notificationFromRow(Map<String, dynamic> row) {
    final payload = row['payload'];
    return AppNotification(
      id: row['id'] as String,
      orgId: row['org_id'] as String,
      userId: row['user_id'] as String,
      type: (row['type'] as String?) ?? 'complaint_task',
      title: row['title'] as String,
      body: (row['body'] as String?) ?? '',
      payload: payload is Map
          ? Map<String, dynamic>.from(payload)
          : const <String, dynamic>{},
      readAt: row['read_at'] != null
          ? DateTime.tryParse(row['read_at'] as String)
          : null,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
