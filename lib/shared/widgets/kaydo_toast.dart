import 'package:flutter/material.dart';

import '../../core/theme/fello_colors.dart';

enum KaydoToastTone { neutral, success, error, info }

/// App-wide transient feedback uses a dialog, never a snackbar.
void showKaydoToast(
  BuildContext context, {
  required String message,
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
    builder: (dialogContext) => AlertDialog(
      icon: Icon(icon, color: accent),
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
