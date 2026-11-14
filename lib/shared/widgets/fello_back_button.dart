import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// iOS-style chevron back control in black, shared across Kaydo screens.
class FelloBackButton extends StatelessWidget {
  const FelloBackButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'Back',
  });

  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        minimumSize: const Size(36, 36),
        onPressed: onPressed,
        child: const Icon(
          CupertinoIcons.back,
          size: 22,
          color: Colors.black,
        ),
      ),
    );
  }
}
