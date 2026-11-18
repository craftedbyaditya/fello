import 'package:flutter/material.dart';

import '../../core/theme/fello_colors.dart';

enum KaydoToastTone { neutral, success, error, info }

/// App-wide transient feedback uses a dialog, never a snackbar.
void showKaydoToast(
  BuildContext context, {
  required String message,
  String? title,
  KaydoToastTone tone = KaydoToastTone.neutral,
  Duration duration = const Duration(seconds: 3),
}) {
  final Color accent;
  final IconData icon;
  switch (tone) {
    case KaydoToastTone.success:
      accent = FelloColors.accent;
      icon = Icons.check_circle_rounded;
    case KaydoToastTone.error:
      accent = FelloColors.danger;
      icon = Icons.error_outline_rounded;
    case KaydoToastTone.neutral:
    case KaydoToastTone.info:
      accent = FelloColors.inkSoft;
      icon = Icons.info_outline_rounded;
  }

  showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tone == KaydoToastTone.error
                          ? FelloColors.danger.withValues(alpha: 0.1)
                          : FelloColors.mist,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title ?? _defaultTitle(tone),
                          style: Theme.of(dialogContext).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          message,
                          style: Theme.of(dialogContext).textTheme.bodyMedium
                              ?.copyWith(
                                color: FelloColors.inkSoft,
                                height: 1.4,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String _defaultTitle(KaydoToastTone tone) {
  return switch (tone) {
    KaydoToastTone.success => 'All set',
    KaydoToastTone.error => 'Something went wrong',
    KaydoToastTone.neutral || KaydoToastTone.info => 'Kaydo',
  };
}
