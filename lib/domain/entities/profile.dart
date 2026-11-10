import 'package:equatable/equatable.dart';

enum ProfileRole { admin, member }

class Profile extends Equatable {
  const Profile({
    required this.id,
    required this.orgId,
    required this.displayName,
    required this.email,
    required this.role,
  });

  final String id;
  final String orgId;
  final String displayName;
  final String email;
  final ProfileRole role;

  Profile copyWith({
    String? id,
    String? orgId,
    String? displayName,
    String? email,
    ProfileRole? role,
  }) {
    return Profile(
      id: id ?? this.id,
      orgId: orgId ?? this.orgId,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      role: role ?? this.role,
    );
  }

  @override
  List<Object?> get props => [id, orgId, displayName, email, role];
}
