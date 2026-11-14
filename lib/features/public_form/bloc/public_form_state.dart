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
    this.turnstileToken,
    this.requireTurnstile = false,
  });

  final PublicFormStatus status;
  final FeedbackForm? form;
  final Map<String, dynamic> answers;
  final String? errorMessage;
  final String? turnstileToken;
  final bool requireTurnstile;

  PublicFormState copyWith({
    PublicFormStatus? status,
    FeedbackForm? form,
    Map<String, dynamic>? answers,
    String? errorMessage,
    String? turnstileToken,
    bool? requireTurnstile,
    bool clearError = false,
    bool clearTurnstile = false,
  }) {
    return PublicFormState(
      status: status ?? this.status,
      form: form ?? this.form,
      answers: answers ?? this.answers,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      turnstileToken:
          clearTurnstile ? null : (turnstileToken ?? this.turnstileToken),
      requireTurnstile: requireTurnstile ?? this.requireTurnstile,
    );
  }

  @override
  List<Object?> get props => [
        status,
        form,
        answers,
        errorMessage,
        turnstileToken,
        requireTurnstile,
      ];
}
