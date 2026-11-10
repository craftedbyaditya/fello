part of 'dashboard_bloc.dart';

enum DashboardStatus { initial, loading, ready, failure }

class DashboardState extends Equatable {
  const DashboardState({
    this.status = DashboardStatus.initial,
    this.orgId,
    this.forms = const [],
    this.responses = const [],
    this.stats,
    this.filters = const ResponseFilters(),
    this.errorMessage,
  });

  final DashboardStatus status;
  final String? orgId;
  final List<FeedbackForm> forms;
  final List<FeedbackResponse> responses;
  final DashboardStats? stats;
  final ResponseFilters filters;
  final String? errorMessage;

  DashboardState copyWith({
    DashboardStatus? status,
    String? orgId,
    List<FeedbackForm>? forms,
    List<FeedbackResponse>? responses,
    DashboardStats? stats,
    ResponseFilters? filters,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DashboardState(
      status: status ?? this.status,
      orgId: orgId ?? this.orgId,
      forms: forms ?? this.forms,
      responses: responses ?? this.responses,
      stats: stats ?? this.stats,
      filters: filters ?? this.filters,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props =>
      [status, orgId, forms, responses, stats, filters, errorMessage];
}
