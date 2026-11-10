import 'package:uuid/uuid.dart';

import '../../domain/entities/organization.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/auth_repository.dart';
import 'mock_store.dart';

class MockAuthRepository implements AuthRepository {
  MockAuthRepository(this._store);

  final MockStore _store;
  static const _uuid = Uuid();

  @override
  Stream<AuthSession?> get authStateChanges async* {
    yield _store.currentSession;
    yield* _store.authStateChanges;
  }

  @override
  AuthSession? get currentSession => _store.currentSession;

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final normalized = email.trim().toLowerCase();
    final expected = _store.passwords[normalized];
    if (expected == null || expected != password) {
      throw AuthFailure('Invalid email or password.');
    }
    final profile = _store.profiles.firstWhere(
      (p) => p.email.toLowerCase() == normalized,
    );
    final org = _store.organizations.firstWhere((o) => o.id == profile.orgId);
    final session = AuthSession(profile: profile, organization: org);
    _store.setSession(session);
    return session;
  }

  @override
  Future<AuthSession> signUp({
    required String email,
    required String password,
    required String organizationName,
    required String displayName,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final normalized = email.trim().toLowerCase();
    if (_store.passwords.containsKey(normalized)) {
      throw AuthFailure('An account with this email already exists.');
    }
    if (password.length < 6) {
      throw AuthFailure('Password must be at least 6 characters.');
    }

    final orgId = _uuid.v4();
    final slug = _slugify(organizationName);
    final org = Organization(
      id: orgId,
      name: organizationName.trim(),
      slug: slug,
      createdAt: DateTime.now(),
    );
    final profile = Profile(
      id: _uuid.v4(),
      orgId: orgId,
      displayName: displayName.trim(),
      email: normalized,
      role: ProfileRole.admin,
    );

    _store.organizations.add(org);
    _store.profiles.add(profile);
    _store.passwords[normalized] = password;

    final session = AuthSession(profile: profile, organization: org);
    _store.setSession(session);
    return session;
  }

  @override
  Future<void> signOut() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _store.setSession(null);
  }

  @override
  Future<Organization> updateOrganization({
    required String name,
    String? slug,
  }) async {
    final session = _store.currentSession;
    if (session == null) throw AuthFailure('Not signed in.');
    final index =
        _store.organizations.indexWhere((o) => o.id == session.organization.id);
    if (index < 0) throw AuthFailure('Organization not found.');
    final updated = session.organization.copyWith(
      name: name.trim(),
      slug: slug?.trim().isNotEmpty == true
          ? _slugify(slug!)
          : session.organization.slug,
    );
    _store.organizations[index] = updated;
    final newSession =
        AuthSession(profile: session.profile, organization: updated);
    _store.setSession(newSession);
    return updated;
  }

  String _slugify(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }
}

class AuthFailure implements Exception {
  AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}
