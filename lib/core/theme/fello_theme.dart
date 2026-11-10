import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'fello_colors.dart';

abstract final class FelloTheme {
  static ThemeData light() {
    final baseText = GoogleFonts.dmSansTextTheme();
    final display = GoogleFonts.fraunces();

    final colorScheme = ColorScheme.light(
      primary: FelloColors.accent,
      onPrimary: Colors.white,
      secondary: FelloColors.inkSoft,
      onSecondary: Colors.white,
      surface: FelloColors.paper,
      onSurface: FelloColors.ink,
      error: FelloColors.danger,
      onError: Colors.white,
      outline: FelloColors.border,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: FelloColors.mist,
      textTheme: baseText.copyWith(
        displayLarge: display.copyWith(
          fontSize: 48,
          fontWeight: FontWeight.w600,
          color: FelloColors.ink,
          height: 1.1,
        ),
        displayMedium: display.copyWith(
          fontSize: 36,
          fontWeight: FontWeight.w600,
          color: FelloColors.ink,
          height: 1.15,
        ),
        headlineLarge: display.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: FelloColors.ink,
        ),
        headlineMedium: display.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: FelloColors.ink,
        ),
        titleLarge: baseText.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: FelloColors.ink,
        ),
        bodyLarge: baseText.bodyLarge?.copyWith(
          color: FelloColors.inkSoft,
          height: 1.5,
        ),
        bodyMedium: baseText.bodyMedium?.copyWith(
          color: FelloColors.inkSoft,
          height: 1.45,
        ),
        labelLarge: baseText.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: FelloColors.paper.withValues(alpha: 0.92),
        foregroundColor: FelloColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: display.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: FelloColors.ink,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FelloColors.paper,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FelloColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FelloColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FelloColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FelloColors.danger),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: FelloColors.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: FelloColors.ink,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: const BorderSide(color: FelloColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: FelloColors.accentDeep),
      ),
      cardTheme: CardThemeData(
        color: FelloColors.paper,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: FelloColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: FelloColors.border,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: FelloColors.ink,
        contentTextStyle: baseText.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
