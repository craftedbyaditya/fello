import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/fello_colors.dart';

class FelloLogo extends StatelessWidget {
  const FelloLogo({
    super.key,
    this.size = 32,
    this.showWordmark = true,
  });

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: FelloColors.accent,
            borderRadius: BorderRadius.circular(size * 0.28),
          ),
          alignment: Alignment.center,
          child: Text(
            'F',
            style: GoogleFonts.fraunces(
              color: Colors.white,
              fontSize: size * 0.55,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
        if (showWordmark) ...[
          SizedBox(width: size * 0.35),
          Text(
            'Fello',
            style: GoogleFonts.fraunces(
              fontSize: size * 0.72,
              fontWeight: FontWeight.w600,
              color: FelloColors.ink,
              height: 1,
            ),
          ),
        ],
      ],
    );
  }
}
