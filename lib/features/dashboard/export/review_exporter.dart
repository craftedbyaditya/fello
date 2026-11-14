import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../presentation/widgets/review_feed.dart';
import 'file_download.dart';

class ReviewExportData {
  const ReviewExportData({
    required this.surveyTitle,
    required this.createdAt,
    required this.avgRating,
    required this.totalReviews,
    required this.reviews,
  });

  final String surveyTitle;
  final DateTime createdAt;
  final double avgRating;
  final int totalReviews;
  final List<ReviewItem> reviews;
}

/// Builds Kaydo-branded PDF + Excel exports for survey reviews.
abstract final class ReviewExporter {
  static const _brandGreen = PdfColor.fromInt(0xFF028C50);
  static const _ink = PdfColor.fromInt(0xFF0B1218);
  static const _muted = PdfColor.fromInt(0xFF5B6573);
  static const _border = PdfColor.fromInt(0xFFEEF2EF);
  static const _soft = PdfColor.fromInt(0xFFE7F7EE);

  static String _slug(String title) {
    final cleaned = title
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return cleaned.isEmpty ? 'survey' : cleaned;
  }

  static String _fileStem(ReviewExportData data) {
    final day = DateFormat('yyyyMMdd').format(DateTime.now());
    return 'kaydo-${_slug(data.surveyTitle)}-reviews-$day';
  }

  static List<String> _questionLabels(ReviewExportData data) {
    if (data.reviews.isEmpty) return const [];
    return [
      for (final answer in data.reviews.first.answers) answer.label,
    ];
  }

  static Future<void> exportPdf(ReviewExportData data) async {
    final bytes = await buildPdf(data);
    downloadBytes(
      bytes: bytes,
      fileName: '${_fileStem(data)}.pdf',
      mimeType: 'application/pdf',
    );
  }

  static Future<void> exportExcel(ReviewExportData data) async {
    final bytes = buildExcel(data);
    downloadBytes(
      bytes: bytes,
      fileName: '${_fileStem(data)}.xlsx',
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  static Future<Uint8List> buildPdf(ReviewExportData data) async {
    final doc = pw.Document(
      title: '${data.surveyTitle} — Kaydo reviews',
      author: 'Kaydo',
      creator: 'Kaydo by Sayge',
    );

    pw.MemoryImage? logo;
    try {
      final logoData =
          await rootBundle.load('assets/images/kaydo_logo.png');
      logo = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {
      logo = null;
    }

    final dateFmt = DateFormat('MMM d, y');
    final exportedAt = DateFormat('MMMM d, y · HH:mm').format(DateTime.now());
    final questions = _questionLabels(data);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 40),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: pw.BoxDecoration(
                color: _brandGreen,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                children: [
                  if (logo != null) ...[
                    pw.Container(
                      width: 28,
                      height: 28,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      padding: const pw.EdgeInsets.all(3),
                      child: pw.Image(logo, fit: pw.BoxFit.contain),
                    ),
                    pw.SizedBox(width: 10),
                  ],
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Kaydo',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'Feedback export',
                          style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Text(
                    'kaydo.sayge.in',
                    style: const pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Text(
              data.surveyTitle.isEmpty ? 'Untitled survey' : data.surveyTitle,
              style: pw.TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Created ${dateFmt.format(data.createdAt)}  ·  Exported $exportedAt',
              style: const pw.TextStyle(color: _muted, fontSize: 9),
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              children: [
                _statChip('Reviews', '${data.totalReviews}'),
                pw.SizedBox(width: 8),
                _statChip('Avg rating', data.avgRating.toStringAsFixed(1)),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Divider(color: _border, thickness: 1),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}  ·  Powered by Kaydo',
            style: const pw.TextStyle(color: _muted, fontSize: 8),
          ),
        ),
        build: (context) {
          if (data.reviews.isEmpty) {
            return [
              pw.Text(
                'No reviews to export yet.',
                style: const pw.TextStyle(color: _muted, fontSize: 11),
              ),
            ];
          }

          return [
            for (final review in data.reviews) ...[
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _border),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                review.displayName,
                                style: pw.TextStyle(
                                  color: _ink,
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                '${dateFmt.format(review.submittedAt)}  ·  ${review.location}',
                                style: const pw.TextStyle(
                                  color: _muted,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: pw.BoxDecoration(
                            color: _soft,
                            borderRadius: pw.BorderRadius.circular(999),
                          ),
                          child: pw.Text(
                            '${review.stars}/5',
                            style: pw.TextStyle(
                              color: _brandGreen,
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (questions.isNotEmpty) ...[
                      pw.SizedBox(height: 8),
                      for (final answer in review.answers)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 4),
                          child: pw.RichText(
                            text: pw.TextSpan(
                              children: [
                                pw.TextSpan(
                                  text: '${answer.label}: ',
                                  style: pw.TextStyle(
                                    color: _muted,
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.TextSpan(
                                  text: answer.displayText,
                                  style: const pw.TextStyle(
                                    color: _ink,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ];
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _statChip(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: pw.BoxDecoration(
        color: _soft,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(color: _muted, fontSize: 9),
          ),
          pw.SizedBox(width: 6),
          pw.Text(
            value,
            style: pw.TextStyle(
              color: _brandGreen,
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static Uint8List buildExcel(ReviewExportData data) {
    final excel = Excel.createExcel();
    final sheet = excel['Reviews'];
    excel.delete('Sheet1');

    final title = data.surveyTitle.isEmpty ? 'Untitled survey' : data.surveyTitle;
    final exportedAt = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    final questions = _questionLabels(data);

    final brandStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#028C50'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      bold: true,
      fontSize: 12,
    );
    final metaStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#E7F7EE'),
      fontColorHex: ExcelColor.fromHexString('#027041'),
      fontSize: 10,
    );
    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#0B1218'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      bold: true,
      fontSize: 10,
    );

    void setCell(int col, int row, String value, {CellStyle? style}) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
      );
      cell.value = TextCellValue(value);
      if (style != null) cell.cellStyle = style;
    }

    setCell(0, 0, 'Kaydo', style: brandStyle);
    setCell(1, 0, 'Feedback export', style: brandStyle);
    setCell(2, 0, 'kaydo.sayge.in', style: brandStyle);

    setCell(0, 1, 'Survey', style: metaStyle);
    setCell(1, 1, title, style: metaStyle);
    setCell(2, 1, 'Exported $exportedAt', style: metaStyle);

    setCell(0, 2, 'Total reviews', style: metaStyle);
    setCell(1, 2, '${data.totalReviews}', style: metaStyle);
    setCell(2, 2, 'Avg rating ${data.avgRating.toStringAsFixed(1)}',
        style: metaStyle);

    final headers = <String>[
      'Respondent',
      'Submitted',
      'Location',
      'Overall rating',
      ...questions,
    ];
    for (var c = 0; c < headers.length; c++) {
      setCell(c, 4, headers[c], style: headerStyle);
    }

    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    for (var r = 0; r < data.reviews.length; r++) {
      final review = data.reviews[r];
      final row = 5 + r;
      setCell(0, row, review.displayName);
      setCell(1, row, dateFmt.format(review.submittedAt));
      setCell(2, row, review.location);
      setCell(3, row, '${review.stars}');
      for (var q = 0; q < questions.length; q++) {
        final answer = q < review.answers.length ? review.answers[q] : null;
        setCell(4 + q, row, answer?.displayText ?? '');
      }
    }

    sheet.setColumnWidth(0, 22);
    sheet.setColumnWidth(1, 18);
    sheet.setColumnWidth(2, 18);
    sheet.setColumnWidth(3, 14);
    for (var q = 0; q < questions.length; q++) {
      sheet.setColumnWidth(4 + q, 28);
    }

    final encoded = excel.encode();
    if (encoded == null) {
      throw StateError('Could not encode Excel workbook.');
    }
    return Uint8List.fromList(encoded);
  }
}
