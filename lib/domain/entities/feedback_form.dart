import 'package:equatable/equatable.dart';

import 'question.dart';

enum FormStatus { draft, published }

class FeedbackForm extends Equatable {
  const FeedbackForm({
    required this.id,
    required this.orgId,
    required this.title,
    required this.description,
    required this.slug,
    required this.status,
    required this.createdAt,
    this.questions = const [],
  });

  final String id;
  final String orgId;
  final String title;
  final String description;
  final String slug;
  final FormStatus status;
  final DateTime createdAt;
  final List<Question> questions;

  bool get isPublished => status == FormStatus.published;

  FeedbackForm copyWith({
    String? id,
    String? orgId,
    String? title,
    String? description,
    String? slug,
    FormStatus? status,
    DateTime? createdAt,
    List<Question>? questions,
  }) {
    return FeedbackForm(
      id: id ?? this.id,
      orgId: orgId ?? this.orgId,
      title: title ?? this.title,
      description: description ?? this.description,
      slug: slug ?? this.slug,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      questions: questions ?? this.questions,
    );
  }

  @override
  List<Object?> get props =>
      [id, orgId, title, description, slug, status, createdAt, questions];
}
