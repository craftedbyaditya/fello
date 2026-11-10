part of 'forms_bloc.dart';

sealed class FormsEvent extends Equatable {
  const FormsEvent();

  @override
  List<Object?> get props => [];
}

final class FormsLoadRequested extends FormsEvent {
  const FormsLoadRequested(this.orgId);
  final String orgId;

  @override
  List<Object?> get props => [orgId];
}

final class FormCreateRequested extends FormsEvent {
  const FormCreateRequested({
    required this.orgId,
    required this.title,
    required this.description,
  });

  final String orgId;
  final String title;
  final String description;

  @override
  List<Object?> get props => [orgId, title, description];
}

final class FormSelected extends FormsEvent {
  const FormSelected(this.formId);
  final String formId;

  @override
  List<Object?> get props => [formId];
}

final class FormUpdated extends FormsEvent {
  const FormUpdated(this.form);
  final FeedbackForm form;

  @override
  List<Object?> get props => [form];
}

final class FormPublishRequested extends FormsEvent {
  const FormPublishRequested(this.formId);
  final String formId;

  @override
  List<Object?> get props => [formId];
}

final class FormDeleteRequested extends FormsEvent {
  const FormDeleteRequested(this.formId);
  final String formId;

  @override
  List<Object?> get props => [formId];
}

final class QuestionUpsertRequested extends FormsEvent {
  const QuestionUpsertRequested(this.question);
  final Question question;

  @override
  List<Object?> get props => [question];
}

final class QuestionDeleteRequested extends FormsEvent {
  const QuestionDeleteRequested(this.questionId);
  final String questionId;

  @override
  List<Object?> get props => [questionId];
}
