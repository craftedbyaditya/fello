part of 'dashboard_bloc.dart';

sealed class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object?> get props => [];
}

final class DashboardLoadRequested extends DashboardEvent {
  const DashboardLoadRequested(this.orgId);
  final String orgId;

  @override
  List<Object?> get props => [orgId];
}

final class DashboardFiltersChanged extends DashboardEvent {
  const DashboardFiltersChanged(this.filters);
  final ResponseFilters filters;

  @override
  List<Object?> get props => [filters];
}
