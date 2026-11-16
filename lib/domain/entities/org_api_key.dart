import 'package:equatable/equatable.dart';

/// Metadata for an org API key. The secret is never stored after creation.
class OrgApiKey extends Equatable {
  const OrgApiKey({
    required this.id,
    required this.name,
    required this.keyPrefix,
    required this.createdAt,
    this.revokedAt,
  });

  final String id;
  final String name;
  final String keyPrefix;
  final DateTime createdAt;
  final DateTime? revokedAt;

  bool get isRevoked => revokedAt != null;

  String get maskedPreview => '$keyPrefix…';

  @override
  List<Object?> get props => [id, name, keyPrefix, createdAt, revokedAt];
}

/// Returned once when a key is generated.
class CreatedOrgApiKey extends Equatable {
  const CreatedOrgApiKey({
    required this.key,
    required this.apiKey,
  });

  final OrgApiKey key;

  /// Full secret — show once, then discard.
  final String apiKey;

  @override
  List<Object?> get props => [key, apiKey];
}
