import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/page_settings_model.dart';

class PdfService {
  /// Generates a paginated PDF document from Quill Delta JSON and page settings.
  static Future<Uint8List> generatePdf({
    required String title,
    required String deltaJson,
    required PageSettingsModel pageSettings,
  }) async {
    final pdf = pw.Document(title: title, author: 'DocuCraft Offline Editor');

    PdfPageFormat pdfFormat;
    switch (pageSettings.format) {
      case PageFormatType.a4:
        pdfFormat = PdfPageFormat.a4;
        break;
      case PageFormatType.letter:
        pdfFormat = PdfPageFormat.letter;
        break;
      case PageFormatType.legal:
        pdfFormat = PdfPageFormat.legal;
        break;
    }

    if (pageSettings.orientation == PageOrientationType.landscape) {
      pdfFormat = pdfFormat.landscape;
    }

    final margins = pw.EdgeInsets.fromLTRB(
      pageSettings.marginLeft,
      pageSettings.marginTop,
      pageSettings.marginRight,
      pageSettings.marginBottom,
    );

    final List<dynamic> ops = jsonDecode(deltaJson) as List<dynamic>;
    final List<pw.Widget> contentWidgets = _buildPdfWidgets(ops);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pdfFormat,
        margin: margins,
        header: (pw.Context context) {
          if (pageSettings.headerText != null && pageSettings.headerText!.isNotEmpty) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(bottom: 12),
              child: pw.Text(
                pageSettings.headerText!,
                style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 9),
              ),
            );
          }
          return pw.SizedBox();
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 12),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  pageSettings.footerText ?? '',
                  style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 9),
                ),
                if (pageSettings.showPageNumbers)
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 9),
                  ),
              ],
            ),
          );
        },
        build: (pw.Context context) => contentWidgets,
      ),
    );

    return await pdf.save();
  }

  static List<pw.Widget> _buildPdfWidgets(List<dynamic> ops) {
    final List<pw.Widget> widgets = [];
    List<pw.InlineSpan> currentSpans = [];

    for (final op in ops) {
      if (op is! Map) continue;
      final insert = op['insert'];
      final attrs = op['attributes'] as Map<String, dynamic>? ?? {};

      if (insert is String) {
        final parts = insert.split('\n');
        for (int i = 0; i < parts.length; i++) {
          final part = parts[i];
          if (part.isNotEmpty) {
            currentSpans.add(_createSpan(part, attrs));
          }

          if (i < parts.length - 1) {
            // Newline - construct paragraph widget
            final pWidget = _createParagraphWidget(currentSpans, attrs);
            widgets.add(pWidget);
            currentSpans = [];
          }
        }
      }
    }

    if (currentSpans.isNotEmpty) {
      widgets.add(_createParagraphWidget(currentSpans, {}));
    }

    return widgets;
  }

  static pw.InlineSpan _createSpan(String text, Map<String, dynamic> attrs) {
    final isBold = attrs['bold'] == true;
    final isItalic = attrs['italic'] == true;
    final isUnderline = attrs['underline'] == true;

    PdfColor textColor = PdfColors.black;
    if (attrs['color'] is String) {
      final hex = (attrs['color'] as String).replaceAll('#', '');
      if (hex.length == 6) {
        final val = int.tryParse('FF$hex', radix: 16);
        if (val != null) textColor = PdfColor.fromInt(val);
      }
    }

    return pw.TextSpan(
      text: text,
      style: pw.TextStyle(
        fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        fontStyle: isItalic ? pw.FontStyle.italic : pw.FontStyle.normal,
        decoration: isUnderline ? pw.TextDecoration.underline : null,
        color: textColor,
        fontSize: 11,
      ),
    );
  }

  static pw.Widget _createParagraphWidget(List<pw.InlineSpan> spans, Map<String, dynamic> attrs) {
    if (spans.isEmpty) {
      return pw.SizedBox(height: 10);
    }

    final headerLevel = attrs['header'];
    pw.TextAlign align = pw.TextAlign.left;
    if (attrs['align'] == 'center') align = pw.TextAlign.center;
    if (attrs['align'] == 'right') align = pw.TextAlign.right;
    if (attrs['align'] == 'justify') align = pw.TextAlign.justify;

    if (headerLevel == 1) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 8),
        child: pw.RichText(
          textAlign: align,
          text: pw.TextSpan(
            children: spans,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF0F6CBD),
            ),
          ),
        ),
      );
    } else if (headerLevel == 2) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 6),
        child: pw.RichText(
          textAlign: align,
          text: pw.TextSpan(
            children: spans,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xFF115EA3),
            ),
          ),
        ),
      );
    } else if (headerLevel == 3) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.RichText(
          textAlign: align,
          text: pw.TextSpan(
            children: spans,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
        ),
      );
    }

    if (attrs['list'] == 'bullet') {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(left: 16, bottom: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('- ', style: const pw.TextStyle(fontSize: 11)),
            pw.Expanded(
              child: pw.RichText(
                textAlign: align,
                text: pw.TextSpan(children: spans),
              ),
            ),
          ],
        ),
      );
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.RichText(
        textAlign: align,
        text: pw.TextSpan(children: spans),
      ),
    );
  }

  /// Saves the generated PDF bytes to disk.
  static Future<File> savePdfFile(String targetPath, Uint8List bytes) async {
    final file = File(targetPath);
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Launches the system print dialog or print preview.
  static Future<void> printDocument(String documentTitle, Uint8List pdfBytes) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: documentTitle,
    );
  }
}
