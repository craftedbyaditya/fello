import 'package:equatable/equatable.dart';

enum ComplaintTaskStatus { open, inProgress, resolved, closed }

enum ComplaintPriority { low, medium, high, critical }

enum ComplaintTaskSource { ai, manual }

/// Board column mapping (UI only — DB keeps open/in_progress/resolved/closed).
enum BoardColumn { backlog, inProgress, done }

extension ComplaintTaskStatusX on ComplaintTaskStatus {
  String get wire => switch (this) {
        ComplaintTaskStatus.open => 'open',
        ComplaintTaskStatus.inProgress => 'in_progress',
        ComplaintTaskStatus.resolved => 'resolved',
        ComplaintTaskStatus.closed => 'closed',
      };

  static ComplaintTaskStatus fromWire(String? value) {
    return switch (value) {
      'in_progress' => ComplaintTaskStatus.inProgress,
      'resolved' => ComplaintTaskStatus.resolved,
      'closed' => ComplaintTaskStatus.closed,
      _ => ComplaintTaskStatus.open,
    };
  }

  String get label => switch (this) {
        ComplaintTaskStatus.open => 'Backlog',
        ComplaintTaskStatus.inProgress => 'In Progress',
        ComplaintTaskStatus.resolved => 'Done',
        ComplaintTaskStatus.closed => 'Done',
      };

  BoardColumn get boardColumn => switch (this) {
        ComplaintTaskStatus.open => BoardColumn.backlog,
        ComplaintTaskStatus.inProgress => BoardColumn.inProgress,
        ComplaintTaskStatus.resolved ||
        ComplaintTaskStatus.closed =>
          BoardColumn.done,
      };

  static ComplaintTaskStatus fromBoardColumn(BoardColumn column) {
    return switch (column) {
      BoardColumn.backlog => ComplaintTaskStatus.open,
      BoardColumn.inProgress => ComplaintTaskStatus.inProgress,
      BoardColumn.done => ComplaintTaskStatus.resolved,
    };
  }
}

extension BoardColumnX on BoardColumn {
  String get label => switch (this) {
        BoardColumn.backlog => 'Backlog',
        BoardColumn.inProgress => 'In Progress',
        BoardColumn.done => 'Done',
      };
}

extension ComplaintPriorityX on ComplaintPriority {
  String get wire => name;

  static ComplaintPriority fromWire(String? value) {
    return ComplaintPriority.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ComplaintPriority.medium,
    );
  }

  String get label => switch (this) {
        ComplaintPriority.low => 'Low',
        ComplaintPriority.medium => 'Medium',
        ComplaintPriority.high => 'High',
        ComplaintPriority.critical => 'Critical',
      };
}

extension ComplaintTaskSourceX on ComplaintTaskSource {
  String get wire => name;

  static ComplaintTaskSource fromWire(String? value) {
    return value == 'manual'
        ? ComplaintTaskSource.manual
        : ComplaintTaskSource.ai;
  }

  String get label => switch (this) {
        ComplaintTaskSource.ai => 'AI Complaint',
        ComplaintTaskSource.manual => 'Manual',
      };
}

class ComplaintTask extends Equatable {
  const ComplaintTask({
    required this.id,
    required this.orgId,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.responseId,
    this.analysisId,
    this.assignedTo,
    this.assigneeName,
    this.dueAt,
    this.resolutionNotes = '',
    this.createdBy,
    this.creatorName,
    this.source = ComplaintTaskSource.ai,
    this.commentCount = 0,
  });

  final String id;
  final String orgId;
  final String? responseId;
  final String? analysisId;
  final String title;
  final String description;
  final String category;
  final ComplaintPriority priority;
  final ComplaintTaskStatus status;
  final String? assignedTo;
  final String? assigneeName;
  final DateTime? dueAt;
  final String resolutionNotes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? creatorName;
  final ComplaintTaskSource source;
  final int commentCount;

  bool get isAi => source == ComplaintTaskSource.ai;

  String get displayCreator =>
      isAi ? 'Kaydo AI' : (creatorName?.trim().isNotEmpty == true
          ? creatorName!
          : 'Teammate');

  String get descriptionPreview {
    final t = description.trim();
    if (t.isEmpty) return '';
    return t.length <= 100 ? t : '${t.substring(0, 97)}…';
  }

  BoardColumn get boardColumn => status.boardColumn;

  ComplaintTask copyWith({
    ComplaintTaskStatus? status,
    String? assignedTo,
    String? assigneeName,
    String? resolutionNotes,
    String? title,
    String? description,
    DateTime? updatedAt,
    int? commentCount,
    String? creatorName,
  }) {
    return ComplaintTask(
      id: id,
      orgId: orgId,
      responseId: responseId,
      analysisId: analysisId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category,
      priority: priority,
      status: status ?? this.status,
      assignedTo: assignedTo ?? this.assignedTo,
      assigneeName: assigneeName ?? this.assigneeName,
      dueAt: dueAt,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy,
      creatorName: creatorName ?? this.creatorName,
      source: source,
      commentCount: commentCount ?? this.commentCount,
    );
  }

  @override
  List<Object?> get props => [
        id,
        orgId,
        responseId,
        analysisId,
        title,
        description,
        category,
        priority,
        status,
        assignedTo,
        assigneeName,
        dueAt,
        resolutionNotes,
        createdAt,
        updatedAt,
        createdBy,
        creatorName,
        source,
        commentCount,
      ];
}

class ComplaintTaskFilters extends Equatable {
  const ComplaintTaskFilters({
    this.status,
    this.priority,
    this.category,
    this.formId,
  });

  final ComplaintTaskStatus? status;
  final ComplaintPriority? priority;
  final String? category;

  /// When set, only tasks linked to responses for this survey.
  final String? formId;

  ComplaintTaskFilters copyWith({
    ComplaintTaskStatus? status,
    ComplaintPriority? priority,
    String? category,
    String? formId,
    bool clearStatus = false,
    bool clearPriority = false,
    bool clearCategory = false,
    bool clearFormId = false,
  }) {
    return ComplaintTaskFilters(
      status: clearStatus ? null : (status ?? this.status),
      priority: clearPriority ? null : (priority ?? this.priority),
      category: clearCategory ? null : (category ?? this.category),
      formId: clearFormId ? null : (formId ?? this.formId),
    );
  }

  @override
  List<Object?> get props => [status, priority, category, formId];
}

class ComplaintInsights extends Equatable {
  const ComplaintInsights({
    required this.openCount,
    required this.resolvedCount,
    required this.byCategory,
    required this.risingCategories,
  });

  final int openCount;
  final int resolvedCount;
  final Map<String, int> byCategory;
  final List<String> risingCategories;

  @override
  List<Object?> get props =>
      [openCount, resolvedCount, byCategory, risingCategories];
}

class TaskComment extends Equatable {
  const TaskComment({
    required this.id,
    required this.orgId,
    required this.taskId,
    required this.authorId,
    required this.authorName,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String orgId;
  final String taskId;
  final String authorId;
  final String authorName;
  final String body;
  final DateTime createdAt;

  @override
  List<Object?> get props =>
      [id, orgId, taskId, authorId, authorName, body, createdAt];
}
