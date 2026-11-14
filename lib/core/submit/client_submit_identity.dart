import 'package:uuid/uuid.dart';

import 'client_submit_identity_stub.dart'
    if (dart.library.html) 'client_submit_identity_web.dart' as impl;

/// Stable anonymous client key + per-attempt submission id for public forms.
class ClientSubmitIdentity {
  ClientSubmitIdentity._();

  static const _uuid = Uuid();

  static String clientKey() {
    final existing = impl.readStoredClientKey();
    if (existing.isNotEmpty) return existing;
    final created = impl.createClientKey();
    impl.writeStoredClientKey(created);
    return created;
  }

  static String newSubmissionId() => _uuid.v4();
}
