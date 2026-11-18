import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/fello_colors.dart';
import '../../core/theme/fello_metrics.dart';

/// Fello text field with a static label above the input (never on the border).
///
/// No hint/placeholder text by design — keep labels explicit and reusable.
/// Single-line fields share [FelloMetrics.controlHeight] across the app.
class FelloTextField extends StatefulWidget {
  const FelloTextField({
    super.key,
    this.label,
    this.helperText,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.onEditingComplete,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.obscureText = false,
    this.showObscureToggle = false,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.inputFormatters,
    this.prefixIcon,
    this.suffixIcon,
  }) : assert(
         controller == null || initialValue == null,
         'Provide either a controller or an initialValue, not both.',
       );

  /// Shown above the field. Omit when the surrounding UI already provides context.
  final String? label;

  /// Optional guidance below the field (not an in-field placeholder).
  final String? helperText;
  final TextEditingController? controller;
  final String? initialValue;
  final FocusNode? focusNode;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final VoidCallback? onEditingComplete;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;

  /// When true, characters are masked. Pair with [showObscureToggle] for passwords.
  final bool obscureText;

  /// Shows an eye icon to reveal/hide the value. Implies password UX.
  final bool showObscureToggle;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? prefixIcon;
  final Widget? suffixIcon;

  @override
  State<FelloTextField> createState() => _FelloTextFieldState();
}

class _FelloTextFieldState extends State<FelloTextField> {
  late bool _obscured = widget.obscureText;

  @override
  void didUpdateWidget(covariant FelloTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.obscureText != widget.obscureText &&
        !widget.showObscureToggle) {
      _obscured = widget.obscureText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLabel = widget.label != null && widget.label!.trim().isNotEmpty;
    final isPassword = widget.obscureText || widget.showObscureToggle;
    final singleLine =
        (_obscured ? 1 : widget.maxLines) == 1 && widget.minLines == null;

    Widget? suffix = widget.suffixIcon;
    if (widget.showObscureToggle) {
      suffix = IconButton(
        onPressed: widget.enabled
            ? () => setState(() => _obscured = !_obscured)
            : null,
        tooltip: _obscured ? 'Show password' : 'Hide password',
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        constraints: FelloMetrics.iconBoxConstraints,
        icon: Icon(
          _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 20,
          color: FelloColors.inkSoft,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasLabel) ...[
          Text(
            widget.label!,
            style: theme.textTheme.labelLarge?.copyWith(
              color: FelloColors.ink,
              fontWeight: FontWeight.w500,
              fontSize: 12.5,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextFormField(
          controller: widget.controller,
          initialValue: widget.controller == null ? widget.initialValue : null,
          focusNode: widget.focusNode,
          validator: widget.validator,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onFieldSubmitted,
          onEditingComplete: widget.onEditingComplete,
          keyboardType: isPassword
              ? TextInputType.visiblePassword
              : widget.keyboardType,
          textInputAction: widget.textInputAction,
          textCapitalization: isPassword
              ? TextCapitalization.none
              : widget.textCapitalization,
          autofillHints: widget.autofillHints,
          obscureText: _obscured,
          obscuringCharacter: '•',
          autocorrect: !isPassword,
          enableSuggestions: !isPassword,
          enabled: widget.enabled,
          readOnly: widget.readOnly,
          autofocus: widget.autofocus,
          maxLines: _obscured ? 1 : widget.maxLines,
          minLines: widget.minLines,
          maxLength: widget.maxLength,
          inputFormatters: widget.inputFormatters,
          textAlignVertical: singleLine
              ? TextAlignVertical.center
              : TextAlignVertical.top,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: FelloColors.ink,
            fontWeight: FontWeight.w500,
            fontSize: 14,
            height: 1.25,
          ),
          cursorColor: FelloColors.accent,
          decoration: InputDecoration(
            floatingLabelBehavior: FloatingLabelBehavior.never,
            helperText: widget.helperText,
            helperMaxLines: 2,
            isDense: true,
            filled: true,
            fillColor: FelloColors.paper,
            contentPadding: singleLine
                ? FelloMetrics.fieldContentPadding
                : FelloMetrics.fieldContentPaddingMultiline,
            // Every one-line field gets an invisible, zero-width suffix slot.
            // It preserves the same 48px input geometry as a password field
            // with an eye icon, without reserving horizontal space for email
            // and other plain inputs. Error/helper text still renders below.
            constraints: singleLine ? FelloMetrics.fieldBoxConstraints : null,
            prefixIcon: widget.prefixIcon,
            suffixIcon: suffix ?? const SizedBox.shrink(),
            prefixIconConstraints: FelloMetrics.iconBoxConstraints,
            suffixIconConstraints: singleLine
                ? FelloMetrics.fieldHeightSuffixConstraints
                : FelloMetrics.iconBoxConstraints,
          ),
        ),
      ],
    );
  }
}
