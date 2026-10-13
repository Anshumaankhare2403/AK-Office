import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ak_office/database/database_service.dart';
import 'package:ak_office/models/activity_model.dart';
import 'package:ak_office/models/document_model.dart';
import 'package:ak_office/models/revision_model.dart';
import 'package:ak_office/repositories/activity_repository.dart';
import 'package:ak_office/repositories/document_repository.dart';
import 'package:ak_office/repositories/revision_repository.dart';

class MockPathProviderPlatform extends PathProviderPlatform with MockPlatformInterfaceMixin {
  final Directory tempDir;
  MockPathProviderPlatform(this.tempDir);

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return tempDir.path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SQLite Database & Repositories Tests', () {
    late Directory tempDir;
    late DatabaseService dbService;
    late DocumentRepository docRepo;
    late ActivityRepository activityRepo;
    late RevisionRepository revisionRepo;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('docucraft_db_test_');
      PathProviderPlatform.instance = MockPathProviderPlatform(tempDir);

      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      dbService = DatabaseService();
      docRepo = DocumentRepository(dbService: dbService);
      activityRepo = ActivityRepository(dbService: dbService);
      revisionRepo = RevisionRepository(dbService: dbService);
    });

    tearDownAll(() async {
      await dbService.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Create, retrieve, search, and delete document', () async {
      final now = DateTime.now();
      final doc = DocumentModel(
        id: 'repo-test-doc-1',
        title: 'Alpha Architecture Document',
        filePath: '${tempDir.path}/alpha.docucraft',
        previewText: 'System design for offline document processing',
        wordCount: 85,
        characterCount: 520,
        createdAt: now,
        updatedAt: now,
        lastOpenedAt: now,
        isPinned: true,
      );

      await docRepo.createDocument(doc);

      final retrieved = await docRepo.getDocumentById(doc.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.title, 'Alpha Architecture Document');
      expect(retrieved.isPinned, true);

      // Search
      final searchResults = await docRepo.searchDocuments('Architecture');
      expect(searchResults.any((d) => d.id == doc.id), true);

      // Delete
      await docRepo.deleteDocument(doc.id);
      final afterDelete = await docRepo.getDocumentById(doc.id);
      expect(afterDelete, isNull);
    });

    test('Audit log records activity and queries today activities', () async {
      final now = DateTime.now();
      final doc = DocumentModel(
        id: 'doc-audit-1',
        title: 'Sprint Backlog',
        filePath: '${tempDir.path}/backlog.docucraft',
        createdAt: now,
        updatedAt: now,
        lastOpenedAt: now,
      );
      await docRepo.createDocument(doc);

      final act = ActivityModel(
        id: 'repo-act-1',
        documentId: doc.id,
        documentTitle: doc.title,
        eventType: ActivityEventType.documentCreated,
        timestamp: now,
        description: 'Created new document "Sprint Backlog"',
      );

      await activityRepo.logActivity(act);

      final todayActs = await activityRepo.getActivitiesToday();
      expect(todayActs.any((a) => a.id == act.id), true);

      // Search activity
      final searchActs = await activityRepo.searchActivities('Backlog');
      expect(searchActs.any((a) => a.id == act.id), true);

      // Clean up
      await activityRepo.clearActivities(documentId: 'doc-audit-1');
      await docRepo.deleteDocument(doc.id);
    });

    test('Save and query document revisions', () async {
      final now = DateTime.now();
      final doc = DocumentModel(
        id: 'doc-rev-1',
        title: 'System Design',
        filePath: '${tempDir.path}/sys.docucraft',
        createdAt: now,
        updatedAt: now,
        lastOpenedAt: now,
      );
      await docRepo.createDocument(doc);

      final rev = RevisionModel(
        id: 'repo-rev-1',
        documentId: doc.id,
        versionNumber: 1,
        timestamp: now,
        snapshotPath: '${tempDir.path}/v1.json',
        summary: 'Initial revision checkpoint',
        wordCount: 120,
      );

      await revisionRepo.saveRevision(rev);

      final revs = await revisionRepo.getRevisionsForDocument(doc.id);
      expect(revs.isNotEmpty, true);
      expect(revs.first.versionNumber, 1);
      expect(revs.first.summary, 'Initial revision checkpoint');

      // Clean up
      await revisionRepo.deleteRevisionsForDocument(doc.id);
      final afterDelete = await revisionRepo.getRevisionsForDocument(doc.id);
      expect(afterDelete.isEmpty, true);
      await docRepo.deleteDocument(doc.id);
    });
  });
}
