import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/org_api_key.dart';
import '../../../domain/plan_limit_failure.dart';
import '../../../domain/repositories/developer_api_repository.dart';

part 'developer_docs_event.dart';
part 'developer_docs_state.dart';

class DeveloperDocsBloc
    extends Bloc<DeveloperDocsEvent, DeveloperDocsState> {
  DeveloperDocsBloc(this._repo) : super(const DeveloperDocsState()) {
    on<DeveloperDocsLoadRequested>(_onLoad);
    on<DeveloperApiKeyCreateRequested>(_onCreate);
    on<DeveloperApiKeyRevokeRequested>(_onRevoke);
    on<DeveloperApiKeySecretCleared>(_onClearSecret);
  }

  final DeveloperApiRepository _repo;

  Future<void> _onLoad(
    DeveloperDocsLoadRequested event,
    Emitter<DeveloperDocsState> emit,
  ) async {
    emit(state.copyWith(status: DeveloperDocsStatus.loading, clearError: true));
    try {
      final keys = await _repo.listKeys();
      emit(
        state.copyWith(
          status: DeveloperDocsStatus.ready,
          keys: keys,
          clearError: true,
        ),
      );
    } on PlanLimitFailure catch (e) {
      emit(
        state.copyWith(
          status: DeveloperDocsStatus.planLocked,
          errorMessage: e.message,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: DeveloperDocsStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onCreate(
    DeveloperApiKeyCreateRequested event,
    Emitter<DeveloperDocsState> emit,
  ) async {
    emit(state.copyWith(busy: true, clearError: true, clearSecret: true));
    try {
      final created = await _repo.createKey(name: event.name);
      final keys = await _repo.listKeys();
      emit(
        state.copyWith(
          busy: false,
          status: DeveloperDocsStatus.ready,
          keys: keys,
          newlyCreatedSecret: created.apiKey,
          infoMessage: 'API key created — copy it now. It won’t be shown again.',
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          busy: false,
          errorMessage: e.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), ''),
        ),
      );
    }
  }

  Future<void> _onRevoke(
    DeveloperApiKeyRevokeRequested event,
    Emitter<DeveloperDocsState> emit,
  ) async {
    emit(state.copyWith(busy: true, clearError: true));
    try {
      await _repo.revokeKey(event.keyId);
      final keys = await _repo.listKeys();
      emit(
        state.copyWith(
          busy: false,
          keys: keys,
          infoMessage: 'API key revoked.',
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          busy: false,
          errorMessage: e.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), ''),
        ),
      );
    }
  }

  void _onClearSecret(
    DeveloperApiKeySecretCleared event,
    Emitter<DeveloperDocsState> emit,
  ) {
    emit(state.copyWith(clearSecret: true, clearInfo: true));
  }
}
