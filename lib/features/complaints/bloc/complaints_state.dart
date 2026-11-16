part of 'complaints_bloc.dart';

enum ComplaintsStatus { initial, loading, ready, failure }

class ComplaintsState extends Equatable {
  const ComplaintsState({
    this.status = ComplaintsStatus.initial,
    this.orgId,
    this.formId,
    this.tasks = const [],
    this.filters = const ComplaintTaskFilters(),
    this.insights,
    this.selectedTaskId,
    this.errorMessage,
  });

  final ComplaintsStatus status;
  final String? orgId;
  final String? formId;
  final List<ComplaintTask> tasks;
  final ComplaintTaskFilters filters;
  final ComplaintInsights? insights;
  final String? selectedTaskId;
  final String? errorMessage;

  ComplaintTask? get selectedTask {
    if (selectedTaskId == null) return null;
    for (final t in tasks) {
      if (t.id == selectedTaskId) return t;
    }
    return null;
  }

  ComplaintsState copyWith({
    ComplaintsStatus? status,
    String? orgId,
    String? formId,
    List<ComplaintTask>? tasks,
    ComplaintTaskFilters? filters,
    ComplaintInsights? insights,
    String? selectedTaskId,
    String? errorMessage,
    bool clearError = false,
    bool clearSelected = false,
  }) {
    return ComplaintsState(
      status: status ?? this.status,
      orgId: orgId ?? this.orgId,
      formId: formId ?? this.formId,
      tasks: tasks ?? this.tasks,
      filters: filters ?? this.filters,
      insights: insights ?? this.insights,
      selectedTaskId:
          clearSelected ? null : (selectedTaskId ?? this.selectedTaskId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        orgId,
        formId,
        tasks,
        filters,
        insights,
        selectedTaskId,
        errorMessage,
      ];
}
