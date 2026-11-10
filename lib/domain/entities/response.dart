import 'package:equatable/equatable.dart';

class Answer extends Equatable {
  const Answer({
    required this.id,
    required this.responseId,
    required this.questionId,
    required this.value,
  });

  final String id;
  final String responseId;
  final String questionId;

  /// Flexible payload: number, string, bool, or list of strings.
  final dynamic value;

  @override
  List<Object?> get props => [id, responseId, questionId, value];
}

class FeedbackResponse extends Equatable {
  const FeedbackResponse({
    required this.id,
    required this.formId,
    required this.submittedAt,
    this.metadata = const {},
    this.answers = const [],
  });

  final String id;
  final String formId;
  final DateTime submittedAt;
  final Map<String, dynamic> metadata;
  final List<Answer> answers;

  FeedbackResponse copyWith({
    String? id,
    String? formId,
    DateTime? submittedAt,
    Map<String, dynamic>? metadata,
    List<Answer>? answers,
  }) {
    return FeedbackResponse(
      id: id ?? this.id,
      formId: formId ?? this.formId,
      submittedAt: submittedAt ?? this.submittedAt,
      metadata: metadata ?? this.metadata,
      answers: answers ?? this.answers,
    );
  }

  @override
  List<Object?> get props => [id, formId, submittedAt, metadata, answers];
}
