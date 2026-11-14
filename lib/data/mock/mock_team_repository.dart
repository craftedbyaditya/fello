import 'package:uuid/uuid.dart';

import '../../domain/auth_failure.dart';
import '../../domain/entities/org_invite.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/team_repository.dart';
import 'mock_store.dart';

class MockTeamRepository implements TeamRepository {
  MockTeamRepository(this._store);

  final MockStore _store;
  static const _uuid = Uuid();

  @override
  Future<List<Profile>> listMembers(String orgId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _store.profiles.where((p) => p.orgId == orgId).toList()
      ..sort((a, b) {
        if (a.isAdmin != b.isAdmin) return a.isAdmin ? -1 : 1;
        return a.displayName.compareTo(b.displayName);
      });
  }

  @override
  Future<List<OrgInvite>> listInvites(String orgId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _store.invites.where((i) => i.orgId == orgId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<List<OrgInvite>> inviteEmployees({
    required String orgId,
    required List<String> emails,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final session = _store.currentSession;
    if (session == null || !session.profile.isAdmin) {
      throw AuthFailure('Only admins can invite employees.');
    }
    if (session.organization.id != orgId) {
      throw AuthFailure('You can only invite people to your workspace.');
    }

    final created = <OrgInvite>[];
    final existingEmails = {
      for (final p in _store.profiles.where((p) => p.orgId == orgId))
        p.email.toLowerCase(),
    };
    final pendingEmails = {
      for (final i in _store.invites.where(
        (i) => i.orgId == orgId && i.isPending,
      ))
        i.email.toLowerCase(),
    };

    for (final raw in emails) {
      final email = raw.trim().toLowerCase();
      if (email.isEmpty || !email.contains('@')) continue;
      if (existingEmails.contains(email) || pendingEmails.contains(email)) {
        continue;
      }
      final invite = OrgInvite(
        id: _uuid.v4(),
        orgId: orgId,
        email: email,
        token: _uuid.v4().replaceAll('-', ''),
        status: InviteStatus.pending,
        createdAt: DateTime.now(),
      );
      _store.invites.add(invite);
      pendingEmails.add(email);
      created.add(invite);
    }
    return created;
  }

  @override
  Future<void> revokeInvite(String inviteId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final session = _store.currentSession;
    if (session == null || !session.profile.isAdmin) {
      throw AuthFailure('Only admins can revoke invites.');
    }
    final index = _store.invites.indexWhere((i) => i.id == inviteId);
    if (index < 0) return;
    final invite = _store.invites[index];
    if (invite.orgId != session.organization.id) {
      throw AuthFailure('Invite not found.');
    }
    _store.invites[index] = OrgInvite(
      id: invite.id,
      orgId: invite.orgId,
      email: invite.email,
      token: invite.token,
      status: InviteStatus.revoked,
      role: invite.role,
      createdAt: invite.createdAt,
      acceptedAt: invite.acceptedAt,
    );
  }

  @override
  Future<InvitePreview?> getInvitePreview(String token) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    OrgInvite? invite;
    for (final i in _store.invites) {
      if (i.token == token) {
        invite = i;
        break;
      }
    }
    if (invite == null) return null;
    final orgIndex =
        _store.organizations.indexWhere((o) => o.id == invite!.orgId);
    if (orgIndex < 0) return null;
    return InvitePreview(
      token: invite.token,
      email: invite.email,
      organizationName: _store.organizations[orgIndex].name,
      status: invite.status,
    );
  }
}
