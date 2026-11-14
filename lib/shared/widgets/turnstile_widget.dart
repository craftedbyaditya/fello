import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/fello_colors.dart';
import 'turnstile_widget_stub.dart'
    if (dart.library.html) 'turnstile_widget_web.dart' as impl;

/// Cloudflare Turnstile (web). When [siteKey] is empty, captcha is skipped.
class TurnstileWidget extends StatelessWidget {
  const TurnstileWidget({
    super.key,
    required this.siteKey,
    required this.onToken,
  });

  final String siteKey;
  final ValueChanged<String?> onToken;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || siteKey.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Verify you are human',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: FelloColors.inkSoft,
              ),
        ),
        const SizedBox(height: 8),
        impl.TurnstilePlatformView(siteKey: siteKey, onToken: onToken),
      ],
    );
  }
}
