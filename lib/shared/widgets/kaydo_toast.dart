import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/fello_colors.dart';
import '../../core/theme/fello_metrics.dart';

enum KaydoToastTone { neutral, success, error, info }

/// Compact floating toast — prefer this over full-width snackbars.
void showKaydoToast(
  BuildContext context, {
  required String message,
  KaydoToastTone tone = KaydoToastTone.neutral,
  Duration duration = const Duration(seconds: 3),
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();

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

  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      duration: duration,
      backgroundColor: Colors.transparent,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      width: 360,
      content: Center(
        child: Material(
          color: FelloColors.ink,
          elevation: 10,
          shadowColor: FelloColors.ink.withValues(alpha: 0.28),
          borderRadius: FelloMetrics.dialogBorderRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: accent),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    message,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
