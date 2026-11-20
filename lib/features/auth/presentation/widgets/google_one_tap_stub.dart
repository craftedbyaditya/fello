import 'package:flutter/material.dart';

class GoogleOneTapPlatform extends StatelessWidget {
  const GoogleOneTapPlatform({
    super.key,
    required this.clientId,
    required this.onCredential,
  });

  final String clientId;
  final ValueChanged<String> onCredential;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
