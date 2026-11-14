import 'package:flutter/material.dart';

/// Official Kaydo wordmark + mark asset.
class FelloLogo extends StatelessWidget {
  const FelloLogo({
    super.key,
    this.size = 32,
    this.showWordmark = true,
  });

  /// Height of the logo image.
  final double size;

  /// Kept for API compatibility; the asset already includes the wordmark.
  final bool showWordmark;

  static const String _assetPath = 'assets/images/kaydo_logo.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _assetPath,
      height: size * 2,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      alignment: Alignment.centerLeft,
    );
  }
}
