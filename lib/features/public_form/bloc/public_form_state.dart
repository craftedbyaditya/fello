part of 'public_form_bloc.dart';

enum PublicFormStatus {
  initial,
  loading,
  ready,
  submitting,
  submitted,
  notFound,
  failure,
}

class PublicFormState extends Equatable {
  const PublicFormState({
    this.status = PublicFormStatus.initial,
    this.form,
    this.answers = const {},
    this.errorMessage,
  });

  final PublicFormStatus status;
  final FeedbackForm? form;
  final Map<String, dynamic> answers;
  final String? errorMessage;

  PublicFormState copyWith({
    PublicFormStatus? status,
    FeedbackForm? form,
    Map<String, dynamic>? answers,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PublicFormState(
      status: status ?? this.status,
      form: form ?? this.form,
      answers: answers ?? this.answers,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, form, answers, errorMessage];
}
