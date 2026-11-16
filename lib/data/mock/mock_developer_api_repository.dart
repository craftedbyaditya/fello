import 'dart:math';

import 'package:uuid/uuid.dart';

import '../../domain/auth_permission_failure.dart';
import '../../domain/entities/org_api_key.dart';
import '../../domain/plan_limit_failure.dart';
import '../../domain/repositories/developer_api_repository.dart';
import 'mock_store.dart';

class _StoredApiKey {
  _StoredApiKey({required this.orgId, required this.key, required this.secret});

  final String orgId;
  OrgApiKey key;
  final String secret;
}

/// In-memory API keys for mock mode.
final Map<String, _StoredApiKey> _mockApiKeyIndex = {};

class MockDeveloperApiRepository implements DeveloperApiRepository {
  MockDeveloperApiRepository(this._store);

  final MockStore _store;
  static const _uuid = Uuid();

  void _assertPro() {
    final session = _store.currentSession;
    if (session == null) {
      throw const AuthPermissionFailure('Sign in required.');
    }
    if (!session.organization.plan.allowsReviewsApi) {
      throw const PlanLimitFailure(
        'Reviews API requires Pro. Upgrade on Billing.',
      );
    }
  }

  void _assertAdmin() {
    final session = _store.currentSession;
    if (session == null || !session.profile.isAdmin) {
      throw const AuthPermissionFailure('Only admins can manage API keys.');
    }
  }

  @override
  Future<List<OrgApiKey>> listKeys() async {
    _assertPro();
    final orgId = _store.currentSession!.organization.id;
    final keys =
        _mockApiKeyIndex.values
            .where((e) => e.orgId == orgId)
            .map((e) => e.key)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return keys;
  }

  @override
  Future<CreatedOrgApiKey> createKey({required String name}) async {
    _assertPro();
    _assertAdmin();
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 80) {
      throw StateError('Key name must be 1–80 characters.');
    }
    final orgId = _store.currentSession!.organization.id;
    final id = _uuid.v4();
    final raw =
        'kay_${List.generate(48, (_) => Random.secure().nextInt(16).toRadixString(16)).join()}';
    final prefix = raw.substring(0, 12);
    final key = OrgApiKey(
      id: id,
      name: trimmed,
      keyPrefix: prefix,
      createdAt: DateTime.now().toUtc(),
    );
    _mockApiKeyIndex[id] = _StoredApiKey(orgId: orgId, key: key, secret: raw);
    return CreatedOrgApiKey(key: key, apiKey: raw);
  }

  @override
  Future<void> revokeKey(String keyId) async {
    _assertPro();
    _assertAdmin();
    final orgId = _store.currentSession!.organization.id;
    final stored = _mockApiKeyIndex[keyId];
    if (stored == null || stored.orgId != orgId) {
      throw StateError('API key not found.');
    }
    if (stored.key.revokedAt != null) return;
    stored.key = OrgApiKey(
      id: stored.key.id,
      name: stored.key.name,
      keyPrefix: stored.key.keyPrefix,
      createdAt: stored.key.createdAt,
      revokedAt: DateTime.now().toUtc(),
    );
  }

  /// Test helper: resolve secret (mock only).
  static String? secretFor(String keyId) => _mockApiKeyIndex[keyId]?.secret;

  static void clearAll() => _mockApiKeyIndex.clear();
}
