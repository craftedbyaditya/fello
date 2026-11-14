import 'package:flutter/material.dart';

import '../../core/theme/fello_colors.dart';
import '../../core/theme/fello_metrics.dart';

/// Compact search control matching [FelloMetrics.controlHeight].
class KaydoSearchField extends StatelessWidget {
  const KaydoSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.onClear,
    this.width = FelloMetrics.searchWidth,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  /// Pass `null` to expand to the parent width.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final hasQuery = controller.text.isNotEmpty;
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      height: FelloMetrics.controlHeight,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: FelloColors.ink,
          fontWeight: FontWeight.w500,
          fontSize: 13.5,
          height: 1.25,
        ),
        cursorColor: FelloColors.accent,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: FelloColors.chartMuted,
            fontSize: 13.5,
            height: 1.25,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: FelloColors.inkSoft,
          ),
          prefixIconConstraints: FelloMetrics.iconBoxConstraints,
          suffixIcon: hasQuery && onClear != null
              ? IconButton(
                  tooltip: 'Clear',
                  onPressed: onClear,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints: FelloMetrics.iconBoxConstraints,
                  icon: const Icon(Icons.close_rounded, size: 18),
                )
              : null,
          suffixIconConstraints: FelloMetrics.iconBoxConstraints,
          isDense: true,
          filled: true,
          fillColor: FelloColors.paper,
          contentPadding: FelloMetrics.fieldContentPadding,
          constraints: FelloMetrics.fieldBoxConstraints,
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
        ),
      ),
    );
  }
}
