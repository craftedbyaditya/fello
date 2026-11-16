import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/complaint_task.dart';
import '../../../domain/repositories/workflow_repository.dart';

part 'complaints_event.dart';
part 'complaints_state.dart';

class ComplaintsBloc extends Bloc<ComplaintsEvent, ComplaintsState> {
  ComplaintsBloc(this._workflow) : super(const ComplaintsState()) {
    on<ComplaintsLoadRequested>(_onLoad);
    on<ComplaintsFiltersChanged>(_onFilters);
    on<ComplaintTaskSelected>(_onSelect);
    on<ComplaintTaskUpdateRequested>(_onUpdate);
  }

  final WorkflowRepository _workflow;

  Future<void> _onLoad(
    ComplaintsLoadRequested event,
    Emitter<ComplaintsState> emit,
  ) async {
    emit(state.copyWith(status: ComplaintsStatus.loading, clearError: true));
    try {
      final filters = state.filters.copyWith(formId: event.formId);
      final tasks = await _workflow.listTasks(
        orgId: event.orgId,
        filters: filters,
      );
      final insights = await _workflow.getComplaintInsights(
        event.orgId,
        formId: event.formId,
      );
      emit(
        state.copyWith(
          status: ComplaintsStatus.ready,
          orgId: event.orgId,
          formId: event.formId,
          filters: filters,
          tasks: tasks,
          insights: insights,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ComplaintsStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onFilters(
    ComplaintsFiltersChanged event,
    Emitter<ComplaintsState> emit,
  ) async {
    final orgId = state.orgId;
    if (orgId == null) return;
    final filters = event.filters.copyWith(formId: state.formId);
    emit(state.copyWith(filters: filters, status: ComplaintsStatus.loading));
    try {
      final tasks = await _workflow.listTasks(
        orgId: orgId,
        filters: filters,
      );
      emit(state.copyWith(status: ComplaintsStatus.ready, tasks: tasks));
    } catch (e) {
      emit(
        state.copyWith(
          status: ComplaintsStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onSelect(
    ComplaintTaskSelected event,
    Emitter<ComplaintsState> emit,
  ) async {
    emit(state.copyWith(selectedTaskId: event.taskId));
  }

  Future<void> _onUpdate(
    ComplaintTaskUpdateRequested event,
    Emitter<ComplaintsState> emit,
  ) async {
    try {
      final updated = await _workflow.updateTask(
        taskId: event.taskId,
        status: event.status,
        assignedTo: event.assignedTo,
        resolutionNotes: event.resolutionNotes,
      );
      final tasks = state.tasks
          .map((t) => t.id == updated.id ? updated : t)
          .toList();
      final insights = state.orgId == null
          ? state.insights
          : await _workflow.getComplaintInsights(
              state.orgId!,
              formId: state.formId,
            );
      emit(
        state.copyWith(
          tasks: tasks,
          insights: insights,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }
}
