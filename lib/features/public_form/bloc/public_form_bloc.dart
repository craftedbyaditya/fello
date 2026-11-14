import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/submit/client_submit_identity.dart';
import '../../../domain/entities/feedback_form.dart';
import '../../../domain/plan_limit_failure.dart';
import '../../../domain/public_answer_validator.dart';
import '../../../domain/repositories/form_repository.dart';
import '../../../domain/repositories/response_repository.dart';
import '../../../domain/submit_guard_failure.dart';

part 'public_form_event.dart';
part 'public_form_state.dart';

class PublicFormBloc extends Bloc<PublicFormEvent, PublicFormState> {
  PublicFormBloc({
    required FormRepository formRepository,
    required ResponseRepository responseRepository,
    bool requireTurnstile = false,
  })  : _formRepository = formRepository,
        _responseRepository = responseRepository,
        super(PublicFormState(requireTurnstile: requireTurnstile)) {
    on<PublicFormLoadRequested>(_onLoad);
    on<PublicFormAnswerChanged>(_onAnswerChanged);
    on<PublicFormTurnstileUpdated>(_onTurnstileUpdated);
    on<PublicFormSubmitted>(_onSubmit);
  }

  final FormRepository _formRepository;
  final ResponseRepository _responseRepository;

  Future<void> _onLoad(
    PublicFormLoadRequested event,
    Emitter<PublicFormState> emit,
  ) async {
    emit(state.copyWith(status: PublicFormStatus.loading, clearError: true));
    try {
      final form = await _formRepository.getPublishedBySlug(event.slug);
      if (form == null) {
        emit(
          state.copyWith(
            status: PublicFormStatus.notFound,
            errorMessage: 'This feedback form is unavailable.',
          ),
        );
        return;
      }
      emit(
        state.copyWith(
          status: PublicFormStatus.ready,
          form: form,
          answers: {},
          clearTurnstile: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: PublicFormStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void _onAnswerChanged(
    PublicFormAnswerChanged event,
    Emitter<PublicFormState> emit,
  ) {
    final answers = Map<String, dynamic>.from(state.answers)
      ..[event.questionId] = event.value;
    emit(state.copyWith(answers: answers, clearError: true));
  }

  void _onTurnstileUpdated(
    PublicFormTurnstileUpdated event,
    Emitter<PublicFormState> emit,
  ) {
    emit(
      state.copyWith(
        turnstileToken: event.token,
        clearError: true,
      ),
    );
  }

  Future<void> _onSubmit(
    PublicFormSubmitted event,
    Emitter<PublicFormState> emit,
  ) async {
    final form = state.form;
    if (form == null) return;

    final clientValidation = PublicAnswerValidator.validate(
      questions: form.questions,
      answers: state.answers,
    );
    if (clientValidation != null) {
      emit(
        state.copyWith(
          status: PublicFormStatus.ready,
          errorMessage: clientValidation,
        ),
      );
      return;
    }

    if (state.requireTurnstile &&
        (state.turnstileToken == null || state.turnstileToken!.isEmpty)) {
      emit(
        state.copyWith(
          status: PublicFormStatus.ready,
          errorMessage: 'Please complete the captcha before submitting.',
        ),
      );
      return;
    }

    emit(state.copyWith(status: PublicFormStatus.submitting, clearError: true));
    try {
      await _responseRepository.submitResponse(
        formId: form.id,
        answersByQuestionId: state.answers,
        metadata: {'source': 'public_web'},
        clientKey: ClientSubmitIdentity.clientKey(),
        submissionId: ClientSubmitIdentity.newSubmissionId(),
        turnstileToken: state.turnstileToken,
      );
      emit(state.copyWith(status: PublicFormStatus.submitted));
    } on PlanLimitFailure catch (e) {
      emit(
        state.copyWith(
          status: PublicFormStatus.ready,
          errorMessage: e.message,
        ),
      );
    } on SubmitGuardFailure catch (e) {
      emit(
        state.copyWith(
          status: PublicFormStatus.ready,
          errorMessage: e.message,
          clearTurnstile: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: PublicFormStatus.ready,
          errorMessage: e.toString().replaceFirst('Bad state: ', ''),
          clearTurnstile: true,
        ),
      );
    }
  }
}
