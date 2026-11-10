part of 'public_form_bloc.dart';

sealed class PublicFormEvent extends Equatable {
  const PublicFormEvent();

  @override
  List<Object?> get props => [];
}

final class PublicFormLoadRequested extends PublicFormEvent {
  const PublicFormLoadRequested(this.slug);
  final String slug;

  @override
  List<Object?> get props => [slug];
}

final class PublicFormAnswerChanged extends PublicFormEvent {
  const PublicFormAnswerChanged({
    required this.questionId,
    required this.value,
  });

  final String questionId;
  final dynamic value;

  @override
  List<Object?> get props => [questionId, value];
}

final class PublicFormSubmitted extends PublicFormEvent {
  const PublicFormSubmitted();
}
