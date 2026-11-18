import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/services.dart' show NetworkAssetBundle, rootBundle;
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
    this.organizationName,
    this.organizationLogoUrl,
  });

  final String surveyTitle;
  final DateTime createdAt;
  final double avgRating;
  final int totalReviews;
  final List<ReviewItem> reviews;
  final String? organizationName;
  final String? organizationLogoUrl;
}

/// Builds Kaydo-branded PDF + Excel exports for survey reviews.
abstract final class ReviewExporter {
  static const _brandGreen = PdfColor.fromInt(0xFF028C50);
  static const _ink = PdfColor.fromInt(0xFF0B1218);
  static const _muted = PdfColor.fromInt(0xFF5B6573);
  static const _border = PdfColor.fromInt(0xFFEEF2EF);
  static const _soft = PdfColor.fromInt(0xFFE7F7EE);
  static const _paper = PdfColor.fromInt(0xFFFAFCFB);

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
    return [for (final answer in data.reviews.first.answers) answer.label];
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
      title: '${data.surveyTitle} - Kaydo reviews',
      author: 'Kaydo',
      creator: 'Kaydo by Sayge',
    );

    pw.MemoryImage? logo;
    try {
      final logoData = await rootBundle.load('assets/images/kaydo_logo.png');
      logo = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {
      logo = null;
    }
    pw.ImageProvider? organizationLogo;
    final organizationLogoUrl = data.organizationLogoUrl?.trim();
    if (organizationLogoUrl != null && organizationLogoUrl.isNotEmpty) {
      try {
        // An absolute key is resolved unchanged. Supplying a real base URI is
        // important on Flutter Web: a bundle rooted at the image URL can turn
        // an empty key into an invalid request instead of fetching the logo.
        final logoData = await NetworkAssetBundle(
          Uri.parse('https://kaydo.sayge.in/'),
        ).load(organizationLogoUrl);
        organizationLogo = pw.MemoryImage(logoData.buffer.asUint8List());
      } catch (_) {
        // A report remains exportable if the workspace logo is unavailable.
      }
    }

    final dateFmt = DateFormat('MMM d, y');
    final exportedAt = DateFormat('MMMM d, y - HH:mm').format(DateTime.now());
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(42, 42, 42, 46),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Row(
              children: [
                if (organizationLogo != null)
                  pw.SizedBox(
                    width: 48,
                    height: 32,
                    child: pw.Image(organizationLogo, fit: pw.BoxFit.contain),
                  ),
                if (organizationLogo != null) pw.SizedBox(width: 10),
                if (data.organizationName?.trim().isNotEmpty == true)
                  pw.Text(
                    data.organizationName!.trim(),
                    style: pw.TextStyle(
                      color: _ink,
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'FEEDBACK REPORT',
              style: pw.TextStyle(
                color: _brandGreen,
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Container(height: 2, color: _brandGreen),
            pw.SizedBox(height: 16),
            pw.Text(
              data.surveyTitle.isEmpty ? 'Untitled survey' : data.surveyTitle,
              style: pw.TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              'Created ${dateFmt.format(data.createdAt)} - Exported $exportedAt',
              style: const pw.TextStyle(color: _muted, fontSize: 8.5),
            ),
            pw.SizedBox(height: 14),
            pw.Row(
              children: [
                pw.Expanded(
                  child: _summaryMetric('Responses', '${data.totalReviews}'),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: _summaryMetric(
                    'Average rating',
                    data.avgRating > 0
                        ? '${data.avgRating.toStringAsFixed(1)} / 5'
                        : '-',
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              'Responses',
              style: pw.TextStyle(
                color: _ink,
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (context) => pw.Container(
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: _border)),
          ),
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            children: [
              pw.UrlLink(
                destination: 'https://kaydo.sayge.in',
                child: pw.Row(
                  children: [
                    pw.Text(
                      'Powered by',
                      style: const pw.TextStyle(color: _muted, fontSize: 8),
                    ),
                    pw.SizedBox(width: 5),
                    if (logo != null)
                      pw.SizedBox(
                        width: 42,
                        height: 14,
                        child: pw.Image(logo, fit: pw.BoxFit.contain),
                      ),
                  ],
                ),
              ),
              pw.Spacer(),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(color: _muted, fontSize: 8),
              ),
            ],
          ),
        ),
        build: (context) {
          if (data.reviews.isEmpty) {
            return [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(18),
                decoration: pw.BoxDecoration(
                  color: _paper,
                  border: pw.Border.all(color: _border),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  'No responses have been collected for this survey yet.',
                  style: const pw.TextStyle(color: _muted, fontSize: 10),
                ),
              ),
            ];
          }

          return [
            for (var index = 0; index < data.reviews.length; index++)
              _responseCard(
                review: data.reviews[index],
                responseNumber: index + 1,
                dateFmt: dateFmt,
              ),
          ];
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _summaryMetric(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        color: _paper,
        border: pw.Border.all(color: _border),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(color: _muted, fontSize: 8)),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              color: _ink,
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _responseCard({
    required ReviewItem review,
    required int responseNumber,
    required DateFormat dateFmt,
  }) {
    final respondent = review.displayName.trim().isEmpty
        ? 'Anonymous respondent'
        : review.displayName;
    final metadata = <String>[dateFmt.format(review.submittedAt)];
    if (review.location.trim().isNotEmpty) metadata.add(review.location);

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(13),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 22,
                height: 22,
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  color: _soft,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  '$responseNumber',
                  style: pw.TextStyle(
                    color: _brandGreen,
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      respondent,
                      style: pw.TextStyle(
                        color: _ink,
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      metadata.join(' - '),
                      style: const pw.TextStyle(color: _muted, fontSize: 8),
                    ),
                  ],
                ),
              ),
              if (review.stars > 0)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: pw.BoxDecoration(
                    color: _soft,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    '${review.stars} / 5',
                    style: pw.TextStyle(
                      color: _brandGreen,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          if (review.answers.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Divider(color: _border, thickness: 0.7),
            pw.SizedBox(height: 8),
            for (final answer in review.answers)
              pw.Container(
                width: double.infinity,
                margin: const pw.EdgeInsets.only(bottom: 6),
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 7,
                ),
                decoration: pw.BoxDecoration(
                  color: _paper,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      answer.label,
                      style: pw.TextStyle(
                        color: _muted,
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      answer.displayText,
                      style: pw.TextStyle(
                        color: _ink,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  static Uint8List buildExcel(ReviewExportData data) {
    final excel = Excel.createExcel();
    final sheet = excel['Reviews'];
    excel.delete('Sheet1');

    final title = data.surveyTitle.isEmpty
        ? 'Untitled survey'
        : data.surveyTitle;
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
    setCell(
      2,
      2,
      'Avg rating ${data.avgRating.toStringAsFixed(1)}',
      style: metaStyle,
    );

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
