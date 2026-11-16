import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/auth_permission_failure.dart';
import '../../domain/entities/org_api_key.dart';
import '../../domain/plan_limit_failure.dart';
import '../../domain/repositories/developer_api_repository.dart';

class SupabaseDeveloperApiRepository implements DeveloperApiRepository {
  SupabaseDeveloperApiRepository(this._client);

  final SupabaseClient _client;

  Never _mapError(PostgrestException e) {
    final msg = e.message;
    if (msg.contains('PLAN_LIMIT_API')) {
      throw const PlanLimitFailure(
        'Reviews API requires Pro. Upgrade on Billing.',
      );
    }
    if (msg.contains('FORBIDDEN')) {
      throw AuthPermissionFailure(
        msg.replaceFirst(RegExp(r'^FORBIDDEN:\s*'), ''),
      );
    }
    throw AuthPermissionFailure(msg);
  }

  @override
  Future<List<OrgApiKey>> listKeys() async {
    try {
      final rows = await _client.rpc('list_org_api_keys');
      return (rows as List)
          .map((r) => _fromRow(Map<String, dynamic>.from(r as Map)))
          .toList();
    } on PostgrestException catch (e) {
      _mapError(e);
    }
  }

  @override
  Future<CreatedOrgApiKey> createKey({required String name}) async {
    try {
      final row = await _client.rpc(
        'create_org_api_key',
        params: {'p_name': name},
      );
      final map = Map<String, dynamic>.from(row as Map);
      final key = OrgApiKey(
        id: map['id'] as String,
        name: map['name'] as String,
        keyPrefix: map['key_prefix'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
      return CreatedOrgApiKey(key: key, apiKey: map['api_key'] as String);
    } on PostgrestException catch (e) {
      _mapError(e);
    }
  }

  @override
  Future<void> revokeKey(String keyId) async {
    try {
      await _client.rpc('revoke_org_api_key', params: {'p_key_id': keyId});
    } on PostgrestException catch (e) {
      _mapError(e);
    }
  }

  OrgApiKey _fromRow(Map<String, dynamic> row) {
    return OrgApiKey(
      id: row['id'] as String,
      name: row['name'] as String,
      keyPrefix: row['key_prefix'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      revokedAt: row['revoked_at'] != null
          ? DateTime.tryParse(row['revoked_at'] as String)
          : null,
    );
  }
}
