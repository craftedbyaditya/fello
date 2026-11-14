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
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: FelloColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(FelloMetrics.dialogRadius),
      ),
    ),
    builder: (context) => _ExportReviewsSheet(data: data),
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
        message: success,
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
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: FelloColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Export reviews',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: FelloColors.ink,
              ),
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
