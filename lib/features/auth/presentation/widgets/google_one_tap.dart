import 'package:flutter/material.dart';

import 'google_one_tap_credential.dart';
import 'google_one_tap_stub.dart'
    if (dart.library.html) 'google_one_tap_web.dart'
    as impl;

/// Starts Google One Tap on the web when a public Google client ID is set.
///
/// This widget intentionally has no visual footprint: Google Identity
/// Services owns the account chooser. The normal Google OAuth button remains
/// available as a reliable fallback when One Tap is not eligible to display.
class GoogleOneTap extends StatelessWidget {
  const GoogleOneTap({
    super.key,
    required this.clientId,
    required this.onCredential,
  });

  final String clientId;
  final ValueChanged<GoogleOneTapCredential> onCredential;

  @override
  Widget build(BuildContext context) {
    if (clientId.trim().isEmpty) return const SizedBox.shrink();
    return impl.GoogleOneTapPlatform(
      clientId: clientId,
      onCredential: onCredential,
    );
  }
}
