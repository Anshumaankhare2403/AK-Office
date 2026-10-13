import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ak_office/services/docx_service.dart';

void main() {
  group('DocxService Tests', () {
    test('Generate DOCX bytes produces valid ZIP with word/document.xml', () async {
      final delta = jsonEncode([
        {'insert': 'DocuCraft Report\n', 'attributes': {'header': 1}},
        {'insert': 'This is a test of bold formatting.\n', 'attributes': {'bold': true}},
        {'insert': 'Bullet point A\n', 'attributes': {'list': 'bullet'}},
        {'insert': 'Standard paragraph text.\n'},
      ]);

      final bytes = await DocxService.generateDocxBytes(
        deltaJson: delta,
        title: 'DocuCraft Report',
      );

      expect(bytes.isNotEmpty, true);
      // Check standard ZIP magic bytes: PK (0x50, 0x4B)
      expect(bytes[0], 0x50);
      expect(bytes[1], 0x4B);

      // Verify saving to temp file and re-importing
      final tempDir = await Directory.systemTemp.createTemp('docucraft_test_');
      final docxFile = File('${tempDir.path}/test_export.docx');
      await docxFile.writeAsBytes(bytes);

      final importResult = await DocxService.importDocx(docxFile.path);
      expect(importResult.suggestedTitle, 'test_export');
      expect(importResult.plainText.contains('DocuCraft Report'), true);
      expect(importResult.plainText.contains('Standard paragraph text'), true);

      // Clean up
      await tempDir.delete(recursive: true);
    });
  });
}
