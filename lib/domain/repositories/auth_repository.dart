import '../entities/organization.dart';
import '../entities/profile.dart';

class AuthSession {
  const AuthSession({
    required this.profile,
    required this.organization,
  });

  final Profile profile;
  final Organization organization;
}

abstract class AuthRepository {
  Stream<AuthSession?> get authStateChanges;
  AuthSession? get currentSession;

  Future<AuthSession> signIn({
    required String email,
    required String password,
  });

  Future<AuthSession> signUp({
    required String email,
    required String password,
    required String organizationName,
    required String displayName,
  });

  Future<void> signOut();

  Future<Organization> updateOrganization({
    required String name,
    String? slug,
  });
}
