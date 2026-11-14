import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'fello_colors.dart';
import 'fello_metrics.dart';

abstract final class FelloTheme {
  static ThemeData light() {
    final poppins = GoogleFonts.poppinsTextTheme();
    final display = GoogleFonts.poppins();

    final colorScheme = ColorScheme.light(
      primary: FelloColors.accent,
      onPrimary: Colors.white,
      secondary: FelloColors.accentLime,
      onSecondary: FelloColors.ink,
      surface: FelloColors.paper,
      onSurface: FelloColors.ink,
      error: FelloColors.danger,
      onError: Colors.white,
      outline: FelloColors.border,
    );

    // Poppins reads larger than many UI fonts — keep sizes a step tighter.
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: FelloColors.paper,
      fontFamily: GoogleFonts.poppins().fontFamily,
      textTheme: poppins.copyWith(
        displayLarge: display.copyWith(
          fontSize: 40,
          fontWeight: FontWeight.w600,
          color: FelloColors.ink,
          height: 1.1,
        ),
        displayMedium: display.copyWith(
          fontSize: 30,
          fontWeight: FontWeight.w600,
          color: FelloColors.ink,
          height: 1.15,
        ),
        headlineLarge: display.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: FelloColors.ink,
          height: 1.25,
        ),
        headlineMedium: display.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: FelloColors.ink,
          height: 1.3,
        ),
        titleLarge: poppins.titleLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: FelloColors.ink,
          height: 1.3,
        ),
        titleMedium: poppins.titleMedium?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: FelloColors.ink,
          height: 1.3,
        ),
        titleSmall: poppins.titleSmall?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: FelloColors.ink,
        ),
        bodyLarge: poppins.bodyLarge?.copyWith(
          fontSize: 14,
          color: FelloColors.inkSoft,
          height: 1.5,
        ),
        bodyMedium: poppins.bodyMedium?.copyWith(
          fontSize: 13,
          color: FelloColors.inkSoft,
          height: 1.45,
        ),
        bodySmall: poppins.bodySmall?.copyWith(
          fontSize: 12,
          color: FelloColors.inkSoft,
          height: 1.4,
        ),
        labelLarge: poppins.labelLarge?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
        ),
        labelMedium: poppins.labelMedium?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        labelSmall: poppins.labelSmall?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: FelloColors.paper,
        foregroundColor: FelloColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: display.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: FelloColors.ink,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FelloColors.paper,
        isDense: true,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        contentPadding: FelloMetrics.fieldContentPadding,
        constraints: FelloMetrics.fieldBoxConstraints,
        prefixIconConstraints: FelloMetrics.iconBoxConstraints,
        suffixIconConstraints: FelloMetrics.iconBoxConstraints,
        border: OutlineInputBorder(
          borderRadius: FelloMetrics.controlBorderRadius,
          borderSide: const BorderSide(color: FelloColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: FelloMetrics.controlBorderRadius,
          borderSide: const BorderSide(color: FelloColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: FelloMetrics.controlBorderRadius,
          borderSide: const BorderSide(color: FelloColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: FelloMetrics.controlBorderRadius,
          borderSide: const BorderSide(color: FelloColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: FelloMetrics.controlBorderRadius,
          borderSide: const BorderSide(color: FelloColors.danger, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: FelloColors.accent,
          foregroundColor: Colors.white,
          minimumSize: FelloMetrics.controlMinSize,
          maximumSize: FelloMetrics.controlMaxSize,
          padding: FelloMetrics.controlPaddingH,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.standard,
          shape: RoundedRectangleBorder(
            borderRadius: FelloMetrics.controlBorderRadius,
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: FelloColors.ink,
          minimumSize: FelloMetrics.controlMinSize,
          maximumSize: FelloMetrics.controlMaxSize,
          padding: FelloMetrics.controlPaddingH,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.standard,
          side: const BorderSide(color: FelloColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: FelloMetrics.controlBorderRadius,
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: FelloColors.accentDeep,
          minimumSize: FelloMetrics.controlMinSize,
          maximumSize: FelloMetrics.controlMaxSize,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.standard,
          textStyle: GoogleFonts.poppins(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: FelloColors.accent,
        foregroundColor: Colors.white,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 20),
        extendedTextStyle: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: FelloColors.paper,
        elevation: 8,
        shadowColor: FelloColors.ink.withValues(alpha: 0.12),
        shape: FelloMetrics.dialogShape,
        titleTextStyle: display.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: FelloColors.ink,
        ),
        contentTextStyle: poppins.bodyMedium?.copyWith(
          fontSize: 14,
          color: FelloColors.inkSoft,
          height: 1.45,
        ),
      ),
      cardTheme: CardThemeData(
        color: FelloColors.paper,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: FelloColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: FelloColors.border,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: Colors.transparent,
        contentTextStyle: poppins.bodyMedium?.copyWith(
          fontSize: 13,
          color: Colors.white,
        ),
        shape: FelloMetrics.dialogShape,
      ),
    );
  }
}
