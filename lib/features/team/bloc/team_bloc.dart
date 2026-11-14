import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/auth_failure.dart';
import '../../../domain/entities/org_invite.dart';
import '../../../domain/entities/profile.dart';
import '../../../domain/repositories/team_repository.dart';

part 'team_event.dart';
part 'team_state.dart';

class TeamBloc extends Bloc<TeamEvent, TeamState> {
  TeamBloc(this._teamRepository) : super(const TeamState()) {
    on<TeamLoadRequested>(_onLoad);
    on<TeamInvitesSubmitted>(_onInvite);
    on<TeamInviteRevokeRequested>(_onRevoke);
  }

  final TeamRepository _teamRepository;

  Future<void> _onLoad(
    TeamLoadRequested event,
    Emitter<TeamState> emit,
  ) async {
    emit(state.copyWith(status: TeamStatus.loading, clearError: true));
    try {
      final members = await _teamRepository.listMembers(event.orgId);
      final invites = await _teamRepository.listInvites(event.orgId);
      emit(
        state.copyWith(
          status: TeamStatus.ready,
          orgId: event.orgId,
          members: members,
          invites: invites,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: TeamStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onInvite(
    TeamInvitesSubmitted event,
    Emitter<TeamState> emit,
  ) async {
    final orgId = state.orgId;
    if (orgId == null) return;
    emit(state.copyWith(status: TeamStatus.saving, clearError: true));
    try {
      final created = await _teamRepository.inviteEmployees(
        orgId: orgId,
        emails: event.emails,
      );
      final invites = await _teamRepository.listInvites(orgId);
      emit(
        state.copyWith(
          status: TeamStatus.ready,
          invites: invites,
          lastCreatedInvites: created,
          infoMessage: created.isEmpty
              ? 'No new invites — those emails are already members or pending.'
              : 'Invited ${created.length} '
                  '${created.length == 1 ? 'person' : 'people'}.',
        ),
      );
    } on AuthFailure catch (e) {
      emit(
        state.copyWith(
          status: TeamStatus.ready,
          errorMessage: e.message,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: TeamStatus.ready,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onRevoke(
    TeamInviteRevokeRequested event,
    Emitter<TeamState> emit,
  ) async {
    final orgId = state.orgId;
    if (orgId == null) return;
    try {
      await _teamRepository.revokeInvite(event.inviteId);
      final invites = await _teamRepository.listInvites(orgId);
      emit(
        state.copyWith(
          status: TeamStatus.ready,
          invites: invites,
          infoMessage: 'Invite revoked.',
        ),
      );
    } on AuthFailure catch (e) {
      emit(state.copyWith(errorMessage: e.message));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }
}
