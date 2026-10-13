import 'package:flutter_test/flutter_test.dart';
import 'package:ak_office/models/document_model.dart';
import 'package:ak_office/models/page_settings_model.dart';

void main() {
  group('DocumentModel & PageSettingsModel Tests', () {
    test('Default page settings have standard A4 dimensions', () {
      const settings = PageSettingsModel();
      expect(settings.format, PageFormatType.a4);
      expect(settings.orientation, PageOrientationType.portrait);
      expect(settings.marginTop, 72.0);
      expect(settings.width, closeTo(595.28, 0.1));
      expect(settings.height, closeTo(841.89, 0.1));
    });

    test('Landscape orientation adjusts width and height', () {
      const settings = PageSettingsModel(orientation: PageOrientationType.landscape);
      expect(settings.orientation, PageOrientationType.landscape);
      expect(settings.width, closeTo(841.89, 0.1));
      expect(settings.height, closeTo(595.28, 0.1));
    });

    test('DocumentModel serialization roundtrip', () {
      final now = DateTime.now();
      final doc = DocumentModel(
        id: 'test-uuid-1',
        title: 'Project Roadmap',
        filePath: 'C:/docs/roadmap.docucraft',
        previewText: 'Quarterly objectives and deliverables',
        wordCount: 150,
        characterCount: 920,
        createdAt: now,
        updatedAt: now,
        lastOpenedAt: now,
        isPinned: true,
        isArchived: false,
        pageSettings: const PageSettingsModel(
          format: PageFormatType.letter,
          headerText: 'Confidential',
        ),
      );

      final map = doc.toMap();
      final reconstructed = DocumentModel.fromMap(map);

      expect(reconstructed.id, doc.id);
      expect(reconstructed.title, doc.title);
      expect(reconstructed.wordCount, 150);
      expect(reconstructed.isPinned, true);
      expect(reconstructed.pageSettings.format, PageFormatType.letter);
      expect(reconstructed.pageSettings.headerText, 'Confidential');
    });
  });
}
