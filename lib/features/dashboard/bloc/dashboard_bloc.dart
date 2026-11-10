import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/dashboard_stats.dart';
import '../../../domain/entities/feedback_form.dart';
import '../../../domain/entities/response.dart';
import '../../../domain/repositories/form_repository.dart';
import '../../../domain/repositories/response_repository.dart';

part 'dashboard_event.dart';
part 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc({
    required ResponseRepository responseRepository,
    required FormRepository formRepository,
  })  : _responseRepository = responseRepository,
        _formRepository = formRepository,
        super(const DashboardState()) {
    on<DashboardLoadRequested>(_onLoad);
    on<DashboardFiltersChanged>(_onFiltersChanged);
  }

  final ResponseRepository _responseRepository;
  final FormRepository _formRepository;

  Future<void> _onLoad(
    DashboardLoadRequested event,
    Emitter<DashboardState> emit,
  ) async {
    emit(state.copyWith(status: DashboardStatus.loading, clearError: true));
    try {
      final forms = await _formRepository.listForms(event.orgId);
      final filters = state.filters;
      final responses = await _responseRepository.listResponses(
        orgId: event.orgId,
        filters: filters,
      );
      final stats = await _responseRepository.getStats(
        orgId: event.orgId,
        filters: filters,
      );
      emit(
        state.copyWith(
          status: DashboardStatus.ready,
          orgId: event.orgId,
          forms: forms,
          responses: responses,
          stats: stats,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: DashboardStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onFiltersChanged(
    DashboardFiltersChanged event,
    Emitter<DashboardState> emit,
  ) async {
    final orgId = state.orgId;
    if (orgId == null) return;
    emit(
      state.copyWith(
        status: DashboardStatus.loading,
        filters: event.filters,
        clearError: true,
      ),
    );
    try {
      final responses = await _responseRepository.listResponses(
        orgId: orgId,
        filters: event.filters,
      );
      final stats = await _responseRepository.getStats(
        orgId: orgId,
        filters: event.filters,
      );
      emit(
        state.copyWith(
          status: DashboardStatus.ready,
          responses: responses,
          stats: stats,
          filters: event.filters,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: DashboardStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}
