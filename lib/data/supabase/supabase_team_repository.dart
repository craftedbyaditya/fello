import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/auth_failure.dart';
import '../../domain/entities/org_invite.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/team_repository.dart';

class SupabaseTeamRepository implements TeamRepository {
  SupabaseTeamRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Profile>> listMembers(String orgId) async {
    final rows = await _client
        .from('profiles')
        .select()
        .eq('org_id', orgId)
        .order('created_at');
    final user = _client.auth.currentUser;
    return (rows as List).map((raw) {
      final row = raw as Map<String, dynamic>;
      final id = row['id'] as String;
      final email = (row['email'] as String?)?.trim();
      final createdRaw = row['created_at'] as String?;
      return Profile(
        id: id,
        orgId: row['org_id'] as String,
        displayName: row['display_name'] as String? ?? '',
        email: (email != null && email.isNotEmpty)
            ? email
            : (id == user?.id ? (user?.email ?? '') : ''),
        role: (row['role'] as String?) == 'employee'
            ? ProfileRole.employee
            : ProfileRole.admin,
        createdAt:
            createdRaw == null ? null : DateTime.parse(createdRaw),
      );
    }).toList()
      ..sort((a, b) {
        if (a.isAdmin != b.isAdmin) return a.isAdmin ? -1 : 1;
        return a.displayName.compareTo(b.displayName);
      });
  }

  @override
  Future<List<OrgInvite>> listInvites(String orgId) async {
    final rows = await _client
        .from('organization_invites')
        .select()
        .eq('org_id', orgId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => _mapInvite(r as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<OrgInvite>> inviteEmployees({
    required String orgId,
    required List<String> emails,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw AuthFailure('Not signed in.');

    final normalized = emails
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.contains('@'))
        .toSet()
        .toList();
    if (normalized.isEmpty) return const [];

    final members = await _client
        .from('profiles')
        .select('email')
        .eq('org_id', orgId);
    final memberEmails = {
      for (final r in members as List)
        ((r as Map)['email'] as String? ?? '').toLowerCase(),
    }..removeWhere((e) => e.isEmpty);

    final pending = await _client
        .from('organization_invites')
        .select('email')
        .eq('org_id', orgId)
        .eq('status', 'pending');
    final pendingEmails = {
      for (final r in pending as List)
        ((r as Map)['email'] as String).toLowerCase(),
    };

    final toInsert = <Map<String, dynamic>>[];
    for (final email in normalized) {
      if (memberEmails.contains(email) || pendingEmails.contains(email)) {
        continue;
      }
      toInsert.add({
        'org_id': orgId,
        'email': email,
        'role': 'employee',
        'invited_by': uid,
      });
    }
    if (toInsert.isEmpty) return const [];

    try {
      final rows = await _client
          .from('organization_invites')
          .insert(toInsert)
          .select();
      return (rows as List)
          .map((r) => _mapInvite(r as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw AuthFailure(
        e.message.isNotEmpty
            ? e.message
            : "We couldn't send those invites. Please try again.",
      );
    }
  }

  @override
  Future<void> revokeInvite(String inviteId) async {
    try {
      await _client
          .from('organization_invites')
          .update({'status': 'revoked'})
          .eq('id', inviteId)
          .eq('status', 'pending');
    } on PostgrestException catch (e) {
      throw AuthFailure(
        e.message.isNotEmpty
            ? e.message
            : "We couldn't revoke that invite.",
      );
    }
  }

  @override
  Future<InvitePreview?> getInvitePreview(String token) async {
    final rows = await _client.rpc(
      'get_invite_preview',
      params: {'invite_token': token},
    );
    if (rows is! List || rows.isEmpty) return null;
    final row = rows.first as Map<String, dynamic>;
    return InvitePreview(
      token: row['token'] as String,
      email: row['email'] as String,
      organizationName: row['organization_name'] as String,
      status: _statusFrom(row['status'] as String?),
    );
  }

  OrgInvite _mapInvite(Map<String, dynamic> row) {
    final acceptedRaw = row['accepted_at'] as String?;
    return OrgInvite(
      id: row['id'] as String,
      orgId: row['org_id'] as String,
      email: row['email'] as String,
      token: row['token'] as String,
      status: _statusFrom(row['status'] as String?),
      role: ProfileRole.employee,
      createdAt: DateTime.parse(row['created_at'] as String),
      acceptedAt:
          acceptedRaw == null ? null : DateTime.parse(acceptedRaw),
    );
  }

  InviteStatus _statusFrom(String? value) {
    return switch (value) {
      'accepted' => InviteStatus.accepted,
      'revoked' => InviteStatus.revoked,
      _ => InviteStatus.pending,
    };
  }
}
