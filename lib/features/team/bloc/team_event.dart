part of 'team_bloc.dart';

sealed class TeamEvent extends Equatable {
  const TeamEvent();

  @override
  List<Object?> get props => [];
}

final class TeamLoadRequested extends TeamEvent {
  const TeamLoadRequested(this.orgId);
  final String orgId;

  @override
  List<Object?> get props => [orgId];
}

final class TeamInvitesSubmitted extends TeamEvent {
  const TeamInvitesSubmitted(this.emails);
  final List<String> emails;

  @override
  List<Object?> get props => [emails];
}

final class TeamInviteRevokeRequested extends TeamEvent {
  const TeamInviteRevokeRequested(this.inviteId);
  final String inviteId;

  @override
  List<Object?> get props => [inviteId];
}
