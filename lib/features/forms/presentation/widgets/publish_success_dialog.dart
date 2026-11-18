import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/fello_colors.dart';
import '../../../../core/theme/fello_metrics.dart';
import '../../../../shared/animations/fade_slide_in.dart';
import '../../../../shared/widgets/kaydo_toast.dart';

Future<void> showPublishSuccessDialog({
  required BuildContext context,
  required String formTitle,
  required String link,
  bool isNewlyPublished = true,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _PublishSuccessDialog(
      formTitle: formTitle,
      link: link,
      isNewlyPublished: isNewlyPublished,
    ),
  );
}

class _PublishSuccessDialog extends StatefulWidget {
  const _PublishSuccessDialog({
    required this.formTitle,
    required this.link,
    required this.isNewlyPublished,
  });

  final String formTitle;
  final String link;
  final bool isNewlyPublished;

  @override
  State<_PublishSuccessDialog> createState() => _PublishSuccessDialogState();
}

class _PublishSuccessDialogState extends State<_PublishSuccessDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..forward();

  late final Animation<double> _scale = CurvedAnimation(
    parent: _controller,
    curve: Curves.elasticOut,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final dialogWidth = (width * 0.56).clamp(420.0, 560.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: FelloMetrics.dialogShape,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 22),
          child: FadeSlideIn(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _scale,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: FelloColors.accentSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 40,
                      color: FelloColors.accentDeep,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  widget.isNewlyPublished ? 'Survey published' : 'Share survey',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  '"${widget.formTitle}" is live. Share the QR code or link with customers.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: FelloColors.mist,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: FelloColors.border),
                  ),
                  child: Column(
                    children: [
                      QrImageView(
                        data: widget.link,
                        size: 180,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: FelloColors.ink,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: FelloColors.ink,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SelectableText(
                        widget.link,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: FelloColors.accentDeep,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: widget.link),
                        );
                        if (context.mounted) {
                          showKaydoToast(
                            context,
                            message: 'Link copied',
                            tone: KaydoToastTone.success,
                          );
                        }
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy link'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
