import 'package:equatable/equatable.dart';

enum QuestionType {
  starRating,
  nps,
  shortText,
  longText,
  yesNo,
  singleChoice,
  multiChoice,
}

class Question extends Equatable {
  const Question({
    required this.id,
    required this.formId,
    required this.type,
    required this.label,
    required this.required,
    required this.sortOrder,
    this.options = const [],
  });

  final String id;
  final String formId;
  final QuestionType type;
  final String label;
  final bool required;
  final List<String> options;
  final int sortOrder;

  Question copyWith({
    String? id,
    String? formId,
    QuestionType? type,
    String? label,
    bool? required,
    List<String>? options,
    int? sortOrder,
  }) {
    return Question(
      id: id ?? this.id,
      formId: formId ?? this.formId,
      type: type ?? this.type,
      label: label ?? this.label,
      required: required ?? this.required,
      options: options ?? this.options,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  bool get hasOptions =>
      type == QuestionType.singleChoice || type == QuestionType.multiChoice;

  @override
  List<Object?> get props =>
      [id, formId, type, label, required, options, sortOrder];
}
