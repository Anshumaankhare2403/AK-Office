import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ak_office/models/page_settings_model.dart';
import 'package:ak_office/services/pdf_service.dart';

void main() {
  group('PdfService Tests', () {
    test('Generate PDF from delta JSON returns valid PDF binary data', () async {
      final delta = jsonEncode([
        {'insert': 'Quarterly Strategy\n', 'attributes': {'header': 1}},
        {'insert': 'Executive overview of deliverables.\n'},
        {'insert': 'Key item 1\n', 'attributes': {'list': 'bullet'}},
        {'insert': 'Key item 2\n', 'attributes': {'list': 'bullet'}},
      ]);

      const settings = PageSettingsModel(
        format: PageFormatType.a4,
        showPageNumbers: true,
        headerText: 'Internal Use Only',
      );

      final pdfBytes = await PdfService.generatePdf(
        title: 'Quarterly Strategy',
        deltaJson: delta,
        pageSettings: settings,
      );

      expect(pdfBytes.isNotEmpty, true);
      // PDF header begins with %PDF- (0x25, 0x50, 0x44, 0x46)
      expect(pdfBytes[0], 0x25); // %
      expect(pdfBytes[1], 0x50); // P
      expect(pdfBytes[2], 0x44); // D
      expect(pdfBytes[3], 0x46); // F
    });
  });
}
