import 'package:equatable/equatable.dart';

class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.orgId,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.payload,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String orgId;
  final String userId;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> payload;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isUnread => readAt == null;

  String? get taskId {
    final value = payload['task_id'];
    return value is String ? value : null;
  }

  String? get formId {
    final value = payload['form_id'];
    return value is String ? value : null;
  }

  @override
  List<Object?> get props =>
      [id, orgId, userId, type, title, body, payload, readAt, createdAt];
}
