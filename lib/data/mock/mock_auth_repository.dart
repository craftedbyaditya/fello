import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../domain/auth_failure.dart';
import '../../domain/entities/business_type.dart';
import '../../domain/entities/org_invite.dart';
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
    required String displayName,
    String? inviteToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final normalized = email.trim().toLowerCase();
    if (_store.passwords.containsKey(normalized)) {
      throw AuthFailure('An account with this email already exists.');
    }
    if (password.length < 6) {
      throw AuthFailure('Password must be at least 6 characters.');
    }

    final token = inviteToken?.trim();
    if (token != null && token.isNotEmpty) {
      final inviteIndex = _store.invites.indexWhere(
        (i) => i.token == token && i.isPending,
      );
      if (inviteIndex < 0) {
        throw AuthFailure('Invite is invalid or already used.');
      }
      final invite = _store.invites[inviteIndex];
      if (invite.email.toLowerCase() != normalized) {
        throw AuthFailure('Use the email address this invite was sent to.');
      }
      final org = _store.organizations.firstWhere((o) => o.id == invite.orgId);
      final profile = Profile(
        id: _uuid.v4(),
        orgId: org.id,
        displayName: displayName.trim(),
        email: normalized,
        role: ProfileRole.employee,
      );
      _store.profiles.add(profile);
      _store.passwords[normalized] = password;
      _store.invites[inviteIndex] = OrgInvite(
        id: invite.id,
        orgId: invite.orgId,
        email: invite.email,
        token: invite.token,
        status: InviteStatus.accepted,
        role: invite.role,
        createdAt: invite.createdAt,
        acceptedAt: DateTime.now(),
      );
      final session = AuthSession(profile: profile, organization: org);
      _store.setSession(session);
      return session;
    }

    final orgId = _uuid.v4();
    final org = Organization(
      id: orgId,
      name: 'My workspace',
      slug: 'my-workspace-${orgId.substring(0, 8)}',
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
  Future<void> requestPasswordReset({required String email}) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final normalized = email.trim().toLowerCase();
    if (!_store.passwords.containsKey(normalized)) {
      // Do not reveal whether the account exists.
      return;
    }
  }

  @override
  Future<void> updatePassword({required String newPassword}) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final session = _store.currentSession;
    if (session == null) throw AuthFailure('Not signed in.');
    if (newPassword.length < 6) {
      throw AuthFailure('Password must be at least 6 characters.');
    }
    _store.passwords[session.profile.email.toLowerCase()] = newPassword;
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

  @override
  Future<Organization> updateWorkspaceLogo({
    List<int>? imageBytes,
    String? contentType,
    String? fileExtension,
    required bool showOnForms,
    bool removeLogo = false,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final session = _store.currentSession;
    if (session == null) throw AuthFailure('Not signed in.');
    if (!session.profile.isAdmin) {
      throw AuthFailure('Only admins can update the workspace logo.');
    }
    if (!session.organization.plan.allowsWorkspaceLogo) {
      throw AuthFailure(
        'Workspace logo is available on paid plans. Upgrade on Billing.',
      );
    }
    final index =
        _store.organizations.indexWhere((o) => o.id == session.organization.id);
    if (index < 0) throw AuthFailure('Organization not found.');

    String? nextUrl = session.organization.logoUrl;
    var clear = false;
    if (removeLogo) {
      nextUrl = null;
      clear = true;
    } else if (imageBytes != null && imageBytes.isNotEmpty) {
      final mime = contentType ?? 'image/png';
      final b64 = base64Encode(imageBytes);
      nextUrl = 'data:$mime;base64,$b64';
    }

    final updated = session.organization.copyWith(
      logoUrl: nextUrl,
      clearLogoUrl: clear,
      showLogoOnForms: showOnForms,
    );
    _store.organizations[index] = updated;
    final newSession =
        AuthSession(profile: session.profile, organization: updated);
    _store.setSession(newSession);
    return updated;
  }

  @override
  Future<AuthSession> completeOnboarding({
    required String organizationName,
    BusinessType? businessType,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final session = _store.currentSession;
    if (session == null) throw AuthFailure('Not signed in.');
    final trimmed = organizationName.trim();
    if (trimmed.isEmpty) {
      throw AuthFailure('Organisation name is required.');
    }

    final index =
        _store.organizations.indexWhere((o) => o.id == session.organization.id);
    if (index < 0) throw AuthFailure('Organization not found.');

    final updated = session.organization.copyWith(
      name: trimmed,
      slug: _slugify(trimmed),
      businessType: businessType,
      clearBusinessType: businessType == null,
      onboardingCompletedAt: DateTime.now(),
    );
    _store.organizations[index] = updated;
    final newSession =
        AuthSession(profile: session.profile, organization: updated);
    _store.setSession(newSession);
    return newSession;
  }

  String _slugify(String input) {
    final slug = input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return slug.isEmpty ? 'workspace' : slug;
  }
}

