part of 'complaints_bloc.dart';

sealed class ComplaintsEvent extends Equatable {
  const ComplaintsEvent();

  @override
  List<Object?> get props => [];
}

final class ComplaintsLoadRequested extends ComplaintsEvent {
  const ComplaintsLoadRequested(this.orgId, {this.formId});
  final String orgId;
  final String? formId;

  @override
  List<Object?> get props => [orgId, formId];
}

final class ComplaintsFiltersChanged extends ComplaintsEvent {
  const ComplaintsFiltersChanged(this.filters);
  final ComplaintTaskFilters filters;

  @override
  List<Object?> get props => [filters];
}

final class ComplaintTaskSelected extends ComplaintsEvent {
  const ComplaintTaskSelected(this.taskId);
  final String? taskId;

  @override
  List<Object?> get props => [taskId];
}

final class ComplaintTaskUpdateRequested extends ComplaintsEvent {
  const ComplaintTaskUpdateRequested({
    required this.taskId,
    this.status,
    this.assignedTo,
    this.resolutionNotes,
  });

  final String taskId;
  final ComplaintTaskStatus? status;
  final String? assignedTo;
  final String? resolutionNotes;

  @override
  List<Object?> get props => [taskId, status, assignedTo, resolutionNotes];
}
