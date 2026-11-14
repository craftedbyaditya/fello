import 'package:equatable/equatable.dart';

import 'profile.dart';

enum InviteStatus { pending, accepted, revoked }

class OrgInvite extends Equatable {
  const OrgInvite({
    required this.id,
    required this.orgId,
    required this.email,
    required this.token,
    required this.status,
    required this.createdAt,
    this.role = ProfileRole.employee,
    this.acceptedAt,
  });

  final String id;
  final String orgId;
  final String email;
  final String token;
  final InviteStatus status;
  final ProfileRole role;
  final DateTime createdAt;
  final DateTime? acceptedAt;

  bool get isPending => status == InviteStatus.pending;

  @override
  List<Object?> get props =>
      [id, orgId, email, token, status, role, createdAt, acceptedAt];
}

class InvitePreview extends Equatable {
  const InvitePreview({
    required this.token,
    required this.email,
    required this.organizationName,
    required this.status,
  });

  final String token;
  final String email;
  final String organizationName;
  final InviteStatus status;

  bool get isPending => status == InviteStatus.pending;

  @override
  List<Object?> get props => [token, email, organizationName, status];
}
