import 'package:equatable/equatable.dart';

enum ProfileRole { admin, employee }

class Profile extends Equatable {
  const Profile({
    required this.id,
    required this.orgId,
    required this.displayName,
    required this.email,
    required this.role,
    this.createdAt,
  });

  final String id;
  final String orgId;
  final String displayName;
  final String email;
  final ProfileRole role;
  final DateTime? createdAt;

  bool get isAdmin => role == ProfileRole.admin;
  bool get isEmployee => role == ProfileRole.employee;

  String get roleLabel => isAdmin ? 'Admin' : 'Employee';

  Profile copyWith({
    String? id,
    String? orgId,
    String? displayName,
    String? email,
    ProfileRole? role,
    DateTime? createdAt,
  }) {
    return Profile(
      id: id ?? this.id,
      orgId: orgId ?? this.orgId,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, orgId, displayName, email, role, createdAt];
}
