import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/feedback_form.dart';
import '../../../domain/entities/question.dart';
import '../../../domain/repositories/form_repository.dart';

part 'forms_event.dart';
part 'forms_state.dart';

class FormsBloc extends Bloc<FormsEvent, FormsState> {
  FormsBloc(this._formRepository) : super(const FormsState()) {
    on<FormsLoadRequested>(_onLoad);
    on<FormCreateRequested>(_onCreate);
    on<FormSelected>(_onSelected);
    on<FormUpdated>(_onUpdated);
    on<FormPublishRequested>(_onPublish);
    on<FormDeleteRequested>(_onDelete);
    on<QuestionUpsertRequested>(_onUpsertQuestion);
    on<QuestionDeleteRequested>(_onDeleteQuestion);
  }

  final FormRepository _formRepository;

  Future<void> _onLoad(
    FormsLoadRequested event,
    Emitter<FormsState> emit,
  ) async {
    emit(state.copyWith(status: FormsStatus.loading, clearError: true));
    try {
      final forms = await _formRepository.listForms(event.orgId);
      emit(
        state.copyWith(
          status: FormsStatus.ready,
          forms: forms,
          orgId: event.orgId,
          selected: state.selected == null
              ? null
              : forms.cast<FeedbackForm?>().firstWhere(
                    (f) => f?.id == state.selected?.id,
                    orElse: () => null,
                  ),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: FormsStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onCreate(
    FormCreateRequested event,
    Emitter<FormsState> emit,
  ) async {
    emit(state.copyWith(status: FormsStatus.saving, clearError: true));
    try {
      final form = await _formRepository.createForm(
        orgId: event.orgId,
        title: event.title,
        description: event.description,
      );
      final forms = await _formRepository.listForms(event.orgId);
      emit(
        state.copyWith(
          status: FormsStatus.ready,
          forms: forms,
          selected: form,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: FormsStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onSelected(FormSelected event, Emitter<FormsState> emit) async {
    emit(state.copyWith(status: FormsStatus.loading));
    final form = await _formRepository.getForm(event.formId);
    emit(
      state.copyWith(
        status: FormsStatus.ready,
        selected: form,
      ),
    );
  }

  Future<void> _onUpdated(FormUpdated event, Emitter<FormsState> emit) async {
    emit(state.copyWith(status: FormsStatus.saving, clearError: true));
    try {
      final updated = await _formRepository.updateForm(event.form);
      final forms = await _formRepository.listForms(updated.orgId);
      emit(
        state.copyWith(
          status: FormsStatus.ready,
          forms: forms,
          selected: updated,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: FormsStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onPublish(
    FormPublishRequested event,
    Emitter<FormsState> emit,
  ) async {
    emit(state.copyWith(status: FormsStatus.saving, clearError: true));
    try {
      final published = await _formRepository.publishForm(event.formId);
      final forms = await _formRepository.listForms(published.orgId);
      emit(
        state.copyWith(
          status: FormsStatus.ready,
          forms: forms,
          selected: published,
          justPublished: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: FormsStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onDelete(
    FormDeleteRequested event,
    Emitter<FormsState> emit,
  ) async {
    final orgId = state.orgId;
    if (orgId == null) return;
    await _formRepository.deleteForm(event.formId);
    final forms = await _formRepository.listForms(orgId);
    emit(
      state.copyWith(
        status: FormsStatus.ready,
        forms: forms,
        clearSelected: state.selected?.id == event.formId,
      ),
    );
  }

  Future<void> _onUpsertQuestion(
    QuestionUpsertRequested event,
    Emitter<FormsState> emit,
  ) async {
    emit(state.copyWith(status: FormsStatus.saving, clearError: true));
    try {
      await _formRepository.upsertQuestion(event.question);
      final form = await _formRepository.getForm(event.question.formId);
      final forms = form == null
          ? state.forms
          : await _formRepository.listForms(form.orgId);
      emit(
        state.copyWith(
          status: FormsStatus.ready,
          forms: forms,
          selected: form,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: FormsStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onDeleteQuestion(
    QuestionDeleteRequested event,
    Emitter<FormsState> emit,
  ) async {
    final formId = state.selected?.id;
    if (formId == null) return;
    await _formRepository.deleteQuestion(event.questionId);
    final form = await _formRepository.getForm(formId);
    emit(state.copyWith(status: FormsStatus.ready, selected: form));
  }
}
