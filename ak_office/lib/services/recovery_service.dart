import '../repositories/document_repository.dart';
import '../repositories/recovery_repository.dart';

class RecoverableDocument {
  final String documentId;
  final String title;
  final String draftDeltaJson;
  final DateTime draftTimestamp;
  final DateTime? originalSavedTimestamp;

  RecoverableDocument({
    required this.documentId,
    required this.title,
    required this.draftDeltaJson,
    required this.draftTimestamp,
    this.originalSavedTimestamp,
  });
}

class RecoveryService {
  final RecoveryRepository _recoveryRepo;
  final DocumentRepository _docRepo;

  RecoveryService({
    RecoveryRepository? recoveryRepo,
    DocumentRepository? docRepo,
  })  : _recoveryRepo = recoveryRepo ?? RecoveryRepository(),
        _docRepo = docRepo ?? DocumentRepository();

  /// Inspects local storage for unsaved drafts from crashes or abrupt terminations.
  Future<List<RecoverableDocument>> checkForRecoverableDrafts() async {
    final drafts = await _recoveryRepo.getAllDrafts();
    final List<RecoverableDocument> result = [];

    for (final draft in drafts) {
      final doc = await _docRepo.getDocumentById(draft.documentId);
      if (doc != null) {
        // If draft is newer than last saved document timestamp, recovery is viable
        if (draft.timestamp.isAfter(doc.updatedAt.add(const Duration(seconds: 2)))) {
          result.add(RecoverableDocument(
            documentId: draft.documentId,
            title: doc.title,
            draftDeltaJson: draft.draftDeltaJson,
            draftTimestamp: draft.timestamp,
            originalSavedTimestamp: doc.updatedAt,
          ));
        } else {
          // Stale draft already saved
          await _recoveryRepo.deleteDraft(draft.documentId);
        }
      } else {
        // Orphaned draft without parent document
        result.add(RecoverableDocument(
          documentId: draft.documentId,
          title: draft.title,
          draftDeltaJson: draft.draftDeltaJson,
          draftTimestamp: draft.timestamp,
        ));
      }
    }

    return result;
  }

  Future<void> discardDraft(String documentId) async {
    await _recoveryRepo.deleteDraft(documentId);
  }
}
