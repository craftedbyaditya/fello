import 'package:flutter/material.dart';

class TurnstilePlatformView extends StatelessWidget {
  const TurnstilePlatformView({
    super.key,
    required this.siteKey,
    required this.onToken,
  });

  final String siteKey;
  final ValueChanged<String?> onToken;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
