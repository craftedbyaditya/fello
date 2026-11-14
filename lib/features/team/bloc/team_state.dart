part of 'team_bloc.dart';

enum TeamStatus { initial, loading, saving, ready, failure }

class TeamState extends Equatable {
  const TeamState({
    this.status = TeamStatus.initial,
    this.orgId,
    this.members = const [],
    this.invites = const [],
    this.lastCreatedInvites = const [],
    this.errorMessage,
    this.infoMessage,
  });

  final TeamStatus status;
  final String? orgId;
  final List<Profile> members;
  final List<OrgInvite> invites;
  final List<OrgInvite> lastCreatedInvites;
  final String? errorMessage;
  final String? infoMessage;

  List<OrgInvite> get pendingInvites =>
      invites.where((i) => i.isPending).toList();

  TeamState copyWith({
    TeamStatus? status,
    String? orgId,
    List<Profile>? members,
    List<OrgInvite>? invites,
    List<OrgInvite>? lastCreatedInvites,
    String? errorMessage,
    String? infoMessage,
    bool clearError = false,
    bool clearInfo = false,
  }) {
    return TeamState(
      status: status ?? this.status,
      orgId: orgId ?? this.orgId,
      members: members ?? this.members,
      invites: invites ?? this.invites,
      lastCreatedInvites: lastCreatedInvites ?? this.lastCreatedInvites,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      infoMessage: clearInfo ? null : (infoMessage ?? this.infoMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        orgId,
        members,
        invites,
        lastCreatedInvites,
        errorMessage,
        infoMessage,
      ];
}
