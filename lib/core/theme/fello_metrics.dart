import 'package:flutter/material.dart';

/// Shared control geometry so buttons, search fields, and inputs align.
abstract final class FelloMetrics {
  /// Single-line control height (buttons, search, text fields).
  static const double controlHeight = 48;

  static const double controlRadius = 10;

  /// Shared corner radius for dialogs / popups (less rounded than cards).
  static const double dialogRadius = 12;

  /// Default width for header search fields.
  static const double searchWidth = 280;

  /// Minimum width for primary/secondary action buttons in footers.
  static const double buttonMinWidth = 120;

  static const Size controlMinSize = Size(0, controlHeight);
  static const Size controlMaxSize = Size(double.infinity, controlHeight);

  static const EdgeInsets controlPaddingH = EdgeInsets.symmetric(horizontal: 16);

  /// Padding inside single-line inputs — keeps ~48px total with border.
  static const EdgeInsets fieldContentPadding =
      EdgeInsets.symmetric(horizontal: 14, vertical: 14);

  static const EdgeInsets fieldContentPaddingMultiline =
      EdgeInsets.symmetric(horizontal: 14, vertical: 12);

  /// Prefix/suffix icons must not inflate field height past [controlHeight].
  static const BoxConstraints iconBoxConstraints = BoxConstraints(
    minWidth: 40,
    minHeight: 40,
    maxWidth: 44,
    maxHeight: 40,
  );

  static const BoxConstraints fieldBoxConstraints = BoxConstraints(
    minHeight: controlHeight,
    maxHeight: controlHeight,
  );

  static BorderRadius get controlBorderRadius =>
      BorderRadius.circular(controlRadius);

  static BorderRadius get dialogBorderRadius =>
      BorderRadius.circular(dialogRadius);

  static ShapeBorder get dialogShape => RoundedRectangleBorder(
        borderRadius: dialogBorderRadius,
      );
}
