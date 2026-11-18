import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'fello_colors.dart';

/// Screen-aware type + spacing for workspace pages.
///
/// Compact (<720), regular (720–1100), comfortable (>1100).
abstract final class FelloTypography {
  static double _width(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static bool isCompact(BuildContext context) => _width(context) < 720;

  static bool isComfortable(BuildContext context) => _width(context) >= 1100;

  static double pagePadding(BuildContext context) {
    if (isCompact(context)) return 16;
    if (isComfortable(context)) return 28;
    return 20;
  }

  /// Workspace pages use the full shell width by default.
  static double contentMaxWidth(BuildContext context) => double.infinity;

  static TextStyle pageTitle(BuildContext context) {
    final size = isCompact(context)
        ? 20.0
        : isComfortable(context)
        ? 24.0
        : 22.0;
    return GoogleFonts.poppins(
      fontSize: size,
      fontWeight: FontWeight.w600,
      color: FelloColors.ink,
      height: 1.25,
    );
  }

  static TextStyle pageSubtitle(BuildContext context) {
    final size = isCompact(context) ? 12.0 : 12.5;
    return GoogleFonts.poppins(
      fontSize: size,
      fontWeight: FontWeight.w400,
      color: FelloColors.inkSoft,
      height: 1.45,
    );
  }

  static TextStyle listTitle(BuildContext context) {
    final size = isCompact(context) ? 14.0 : 15.0;
    return GoogleFonts.poppins(
      fontSize: size,
      fontWeight: FontWeight.w600,
      color: FelloColors.ink,
      height: 1.3,
    );
  }

  static TextStyle listBody(BuildContext context) {
    final size = isCompact(context) ? 12.5 : 13.0;
    return GoogleFonts.poppins(
      fontSize: size,
      fontWeight: FontWeight.w400,
      color: FelloColors.inkSoft,
      height: 1.4,
    );
  }

  static TextStyle chip(BuildContext context) {
    return GoogleFonts.poppins(
      fontSize: isCompact(context) ? 11.0 : 12.0,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    );
  }
}

/// Shared workspace page header with responsive title/subtitle sizing.
class FelloPageHeader extends StatelessWidget {
  const FelloPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: FelloTypography.pageTitle(context)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: FelloTypography.pageSubtitle(context)),
        ],
      ],
    );

    if (trailing == null) return titleBlock;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [titleBlock, const SizedBox(height: 12), trailing!],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 16),
            trailing!,
          ],
        );
      },
    );
  }
}
