import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/fello_colors.dart';
import '../../../../core/theme/fello_metrics.dart';
import '../../../../shared/widgets/kaydo_toast.dart';
import '../../export/review_exporter.dart';

Future<void> showExportReviewsSheet({
  required BuildContext context,
  required ReviewExportData data,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      shape: FelloMetrics.dialogShape,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: _ExportReviewsSheet(data: data),
      ),
    ),
  );
}

class _ExportReviewsSheet extends StatefulWidget {
  const _ExportReviewsSheet({required this.data});

  final ReviewExportData data;

  @override
  State<_ExportReviewsSheet> createState() => _ExportReviewsSheetState();
}

class _ExportReviewsSheetState extends State<_ExportReviewsSheet> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String success) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      Navigator.pop(context);
      showKaydoToast(
        context,
        title: success == 'PDF downloaded'
            ? 'Your PDF is ready'
            : 'Your Excel file is ready',
        message: success == 'PDF downloaded'
            ? 'Your feedback report has been downloaded.'
            : 'Your feedback spreadsheet has been downloaded.',
        tone: KaydoToastTone.success,
      );
    } catch (e) {
      if (!mounted) return;
      showKaydoToast(
        context,
        message: 'Export failed. Please try again.',
        tone: KaydoToastTone.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Export reviews',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: FelloColors.ink,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Download a Kaydo-branded PDF report or Excel spreadsheet.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: FelloColors.inkSoft,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: FelloMetrics.controlHeight,
              child: OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => ReviewExporter.exportPdf(widget.data),
                        'PDF downloaded',
                      ),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Download PDF'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: FelloMetrics.controlHeight,
              child: FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => ReviewExporter.exportExcel(widget.data),
                        'Excel downloaded',
                      ),
                icon: const Icon(Icons.grid_on_outlined, size: 18),
                label: const Text('Download Excel'),
              ),
            ),
            if (_busy) ...[
              const SizedBox(height: 16),
              const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
