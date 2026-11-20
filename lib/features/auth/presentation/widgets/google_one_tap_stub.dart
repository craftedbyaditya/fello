import 'package:flutter/material.dart';

import 'google_one_tap_credential.dart';

class GoogleOneTapPlatform extends StatelessWidget {
  const GoogleOneTapPlatform({
    super.key,
    required this.clientId,
    required this.onCredential,
  });

  final String clientId;
  final ValueChanged<GoogleOneTapCredential> onCredential;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
