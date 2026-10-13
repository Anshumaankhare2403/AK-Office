import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../core/constants/app_constants.dart';
import '../core/utilities/file_utils.dart';
import '../models/activity_model.dart';
import '../models/document_model.dart';
import '../models/page_settings_model.dart';
import '../models/revision_model.dart';
import '../repositories/activity_repository.dart';
import '../repositories/document_repository.dart';
import '../repositories/recovery_repository.dart';
import '../repositories/revision_repository.dart';

class DocumentService {
  final DocumentRepository _docRepo;
  final ActivityRepository _activityRepo;
  final RevisionRepository _revisionRepo;
  final RecoveryRepository _recoveryRepo;
  final Uuid _uuid;

  DocumentService({
    DocumentRepository? docRepo,
    ActivityRepository? activityRepo,
    RevisionRepository? revisionRepo,
    RecoveryRepository? recoveryRepo,
  })  : _docRepo = docRepo ?? DocumentRepository(),
        _activityRepo = activityRepo ?? ActivityRepository(),
        _revisionRepo = revisionRepo ?? RevisionRepository(),
        _recoveryRepo = recoveryRepo ?? RecoveryRepository(),
        _uuid = const Uuid();

  /// Creates a new document with an initial empty delta.
  Future<DocumentModel> createNewDocument({
    String title = 'Untitled Document',
    PageSettingsModel pageSettings = const PageSettingsModel(),
    String? initialContentJson,
  }) async {
    final id = _uuid.v4();
    final docsDir = await FileUtils.getDocumentsDirectory();
    final safeTitle = FileUtils.sanitizeFileName(title);
    final filePath = p.join(docsDir.path, '$safeTitle-$id${AppConstants.docExtension}');

    final defaultDelta = initialContentJson ?? jsonEncode([
      {'insert': '\n'}
    ]);

    await FileUtils.writeAtomically(filePath, defaultDelta);

    final now = DateTime.now();
    final doc = DocumentModel(
      id: id,
      title: title,
      filePath: filePath,
      previewText: '',
      wordCount: 0,
      characterCount: 0,
      createdAt: now,
      updatedAt: now,
      lastOpenedAt: now,
      pageSettings: pageSettings,
    );

    await _docRepo.createDocument(doc);

    // Initial revision snapshot
    await _saveRevisionSnapshot(id, 1, defaultDelta, 'Initial document creation', 0);

    // Log activity
    await _activityRepo.logActivity(ActivityModel(
      id: _uuid.v4(),
      documentId: id,
      documentTitle: title,
      eventType: ActivityEventType.documentCreated,
      timestamp: now,
      description: 'Created new document "$title"',
      metadata: {'filePath': filePath},
    ));

    return doc;
  }

  /// Loads the delta JSON content for a document from disk.
  Future<String> loadDocumentContent(DocumentModel doc) async {
    final file = File(doc.filePath);
    if (!await file.exists()) {
      throw FileSystemException('Document file not found at ${doc.filePath}', doc.filePath);
    }
    final content = await file.readAsString();
    await _docRepo.updateLastOpened(doc.id);

    await _activityRepo.logActivity(ActivityModel(
      id: _uuid.v4(),
      documentId: doc.id,
      documentTitle: doc.title,
      eventType: ActivityEventType.documentOpened,
      timestamp: DateTime.now(),
      description: 'Opened document "${doc.title}"',
    ));

    return content;
  }

  /// Saves document delta JSON atomically to disk and updates database metadata.
  Future<DocumentModel> saveDocument({
    required DocumentModel doc,
    required String deltaJson,
    required String plainText,
    bool createRevision = false,
    String? revisionSummary,
  }) async {
    final words = _countWords(plainText);
    final chars = plainText.replaceAll(RegExp(r'\s'), '').length;
    final preview = plainText.length > 200 ? plainText.substring(0, 200).trim() : plainText.trim();

    await FileUtils.writeAtomically(doc.filePath, deltaJson);

    final now = DateTime.now();
    final updatedDoc = doc.copyWith(
      wordCount: words,
      characterCount: chars,
      previewText: preview,
      updatedAt: now,
    );

    await _docRepo.updateDocument(updatedDoc);

    // Remove any crash recovery draft since document is cleanly saved
    await _recoveryRepo.deleteDraft(doc.id);

    // Create revision checkpoint if requested
    if (createRevision) {
      final revisions = await _revisionRepo.getRevisionsForDocument(doc.id);
      final nextVersion = revisions.isEmpty ? 2 : revisions.first.versionNumber + 1;
      await _saveRevisionSnapshot(
        doc.id,
        nextVersion,
        deltaJson,
        revisionSummary ?? 'Saved version $nextVersion',
        words,
      );
    }

    await _activityRepo.logActivity(ActivityModel(
      id: _uuid.v4(),
      documentId: doc.id,
      documentTitle: doc.title,
      eventType: ActivityEventType.documentSaved,
      timestamp: now,
      description: 'Saved document "${doc.title}" ($words words)',
      metadata: {'wordCount': words, 'characterCount': chars},
    ));

    return updatedDoc;
  }

  /// Saves a draft for crash recovery during editing.
  Future<void> saveDraft(String docId, String title, String deltaJson) async {
    await _recoveryRepo.saveDraft(docId, title, deltaJson);
  }

  /// Renames a document and renames its physical file safely.
  Future<DocumentModel> renameDocument(DocumentModel doc, String newTitle) async {
    final oldFile = File(doc.filePath);
    final safeNewTitle = FileUtils.sanitizeFileName(newTitle);
    final newFilePath = p.join(oldFile.parent.path, '$safeNewTitle-${doc.id}${AppConstants.docExtension}');

    if (await oldFile.exists()) {
      await oldFile.rename(newFilePath);
    }

    final updatedDoc = doc.copyWith(
      title: newTitle,
      filePath: newFilePath,
      updatedAt: DateTime.now(),
    );

    await _docRepo.updateDocument(updatedDoc);

    await _activityRepo.logActivity(ActivityModel(
      id: _uuid.v4(),
      documentId: doc.id,
      documentTitle: newTitle,
      eventType: ActivityEventType.documentRenamed,
      timestamp: DateTime.now(),
      description: 'Renamed document from "${doc.title}" to "$newTitle"',
    ));

    return updatedDoc;
  }

  /// Duplicates a document.
  Future<DocumentModel> duplicateDocument(DocumentModel sourceDoc) async {
    final content = await loadDocumentContent(sourceDoc);
    return await createNewDocument(
      title: '${sourceDoc.title} (Copy)',
      pageSettings: sourceDoc.pageSettings,
      initialContentJson: content,
    );
  }

  /// Deletes a document, its physical file, revisions, and logs the action.
  Future<void> deleteDocument(DocumentModel doc) async {
    final file = File(doc.filePath);
    if (await file.exists()) {
      await file.delete();
    }

    // Clean revisions directory snapshots
    final revisions = await _revisionRepo.getRevisionsForDocument(doc.id);
    for (final rev in revisions) {
      final snapFile = File(rev.snapshotPath);
      if (await snapFile.exists()) {
        await snapFile.delete();
      }
    }

    await _revisionRepo.deleteRevisionsForDocument(doc.id);
    await _recoveryRepo.deleteDraft(doc.id);
    await _docRepo.deleteDocument(doc.id);

    await _activityRepo.logActivity(ActivityModel(
      id: _uuid.v4(),
      documentId: null, // detached because document deleted
      documentTitle: doc.title,
      eventType: ActivityEventType.documentDeleted,
      timestamp: DateTime.now(),
      description: 'Deleted document "${doc.title}"',
    ));
  }

  /// Restores a previous revision snapshot into the document.
  Future<String> restoreRevision(DocumentModel doc, RevisionModel revision) async {
    final snapFile = File(revision.snapshotPath);
    if (!await snapFile.exists()) {
      throw FileSystemException('Snapshot file not found', revision.snapshotPath);
    }

    final restoredDelta = await snapFile.readAsString();
    await FileUtils.writeAtomically(doc.filePath, restoredDelta);

    final now = DateTime.now();
    await _docRepo.updateDocument(doc.copyWith(updatedAt: now));

    await _activityRepo.logActivity(ActivityModel(
      id: _uuid.v4(),
      documentId: doc.id,
      documentTitle: doc.title,
      eventType: ActivityEventType.versionRestored,
      timestamp: now,
      description: 'Restored revision #${revision.versionNumber} ("${revision.summary}")',
      metadata: {'versionNumber': revision.versionNumber},
    ));

    return restoredDelta;
  }

  Future<void> _saveRevisionSnapshot(
    String docId,
    int versionNumber,
    String deltaJson,
    String summary,
    int wordCount,
  ) async {
    final revDir = await FileUtils.getRevisionsDirectory();
    final snapshotPath = p.join(revDir.path, '$docId-v$versionNumber.json');
    await FileUtils.writeAtomically(snapshotPath, deltaJson);

    final rev = RevisionModel(
      id: _uuid.v4(),
      documentId: docId,
      versionNumber: versionNumber,
      timestamp: DateTime.now(),
      snapshotPath: snapshotPath,
      summary: summary,
      wordCount: wordCount,
    );
    await _revisionRepo.saveRevision(rev);
  }

  int _countWords(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }
}
