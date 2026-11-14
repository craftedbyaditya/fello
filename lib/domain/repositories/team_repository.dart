import '../entities/org_invite.dart';
import '../entities/profile.dart';

abstract class TeamRepository {
  Future<List<Profile>> listMembers(String orgId);

  Future<List<OrgInvite>> listInvites(String orgId);

  /// Creates pending employee invites. Returns created rows (skips duplicates).
  Future<List<OrgInvite>> inviteEmployees({
    required String orgId,
    required List<String> emails,
  });

  Future<void> revokeInvite(String inviteId);

  Future<InvitePreview?> getInvitePreview(String token);
}
