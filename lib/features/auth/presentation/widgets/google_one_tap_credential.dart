/// A Google Identity Services credential together with the raw nonce used to
/// request it. The nonce is deliberately kept alongside the token so the
/// exchange cannot accidentally omit the matching verification value.
class GoogleOneTapCredential {
  const GoogleOneTapCredential({required this.idToken, required this.nonce});

  final String idToken;
  final String nonce;
}
