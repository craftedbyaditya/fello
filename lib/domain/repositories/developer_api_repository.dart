import '../entities/org_api_key.dart';

abstract class DeveloperApiRepository {
  Future<List<OrgApiKey>> listKeys();

  Future<CreatedOrgApiKey> createKey({required String name});

  Future<void> revokeKey(String keyId);
}
