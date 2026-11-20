import 'package:equatable/equatable.dart';

class Answer extends Equatable {
  const Answer({
    required this.id,
    required this.responseId,
    required this.questionId,
    required this.value,
    this.questionLabel,
    this.questionType,
  });

  final String id;
  final String responseId;
  final String questionId;

  /// Immutable copy of the question as it was when this response was given.
  final String? questionLabel;
  final String? questionType;

  /// Flexible payload: number, string, bool, or list of strings.
  final dynamic value;

  @override
  List<Object?> get props => [
    id,
    responseId,
    questionId,
    value,
    questionLabel,
    questionType,
  ];
}

class FeedbackResponse extends Equatable {
  const FeedbackResponse({
    required this.id,
    required this.formId,
    required this.submittedAt,
    this.formVersionId,
    this.formVersion,
    this.metadata = const {},
    this.answers = const [],
    this.isPublic = false,
  });

  final String id;
  final String formId;
  final DateTime submittedAt;

  /// Immutable published survey version used for this response. Older
  /// responses are backfilled to the first available version.
  final String? formVersionId;
  final int? formVersion;
  final Map<String, dynamic> metadata;
  final List<Answer> answers;

  /// Admin-approved for Reviews API / public display.
  final bool isPublic;

  FeedbackResponse copyWith({
    String? id,
    String? formId,
    DateTime? submittedAt,
    String? formVersionId,
    int? formVersion,
    Map<String, dynamic>? metadata,
    List<Answer>? answers,
    bool? isPublic,
  }) {
    return FeedbackResponse(
      id: id ?? this.id,
      formId: formId ?? this.formId,
      submittedAt: submittedAt ?? this.submittedAt,
      formVersionId: formVersionId ?? this.formVersionId,
      formVersion: formVersion ?? this.formVersion,
      metadata: metadata ?? this.metadata,
      answers: answers ?? this.answers,
      isPublic: isPublic ?? this.isPublic,
    );
  }

  @override
  List<Object?> get props => [
    id,
    formId,
    submittedAt,
    formVersionId,
    formVersion,
    metadata,
    answers,
    isPublic,
  ];
}
