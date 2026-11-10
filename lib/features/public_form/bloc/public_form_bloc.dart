import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/feedback_form.dart';
import '../../../domain/repositories/form_repository.dart';
import '../../../domain/repositories/response_repository.dart';

part 'public_form_event.dart';
part 'public_form_state.dart';

class PublicFormBloc extends Bloc<PublicFormEvent, PublicFormState> {
  PublicFormBloc({
    required FormRepository formRepository,
    required ResponseRepository responseRepository,
  })  : _formRepository = formRepository,
        _responseRepository = responseRepository,
        super(const PublicFormState()) {
    on<PublicFormLoadRequested>(_onLoad);
    on<PublicFormAnswerChanged>(_onAnswerChanged);
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

  Future<void> _onSubmit(
    PublicFormSubmitted event,
    Emitter<PublicFormState> emit,
  ) async {
    final form = state.form;
    if (form == null) return;
    emit(state.copyWith(status: PublicFormStatus.submitting, clearError: true));
    try {
      await _responseRepository.submitResponse(
        formId: form.id,
        answersByQuestionId: state.answers,
        metadata: {'source': 'public_web'},
      );
      emit(state.copyWith(status: PublicFormStatus.submitted));
    } catch (e) {
      emit(
        state.copyWith(
          status: PublicFormStatus.ready,
          errorMessage: e.toString().replaceFirst('Bad state: ', ''),
        ),
      );
    }
  }
}
