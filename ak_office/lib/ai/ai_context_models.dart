import '../models/activity_model.dart';
import '../models/document_model.dart';
import '../models/revision_model.dart';

class AiPromptContext {
  final String userPrompt;
  final DocumentModel? currentDocument;
  final String currentDocumentPlainText;
  final String? selectedText;
  final int cursorPosition;
  final List<ActivityModel> recentActivities;
  final List<RevisionModel> documentRevisions;

  AiPromptContext({
    required this.userPrompt,
    this.currentDocument,
    this.currentDocumentPlainText = '',
    this.selectedText,
    this.cursorPosition = 0,
    this.recentActivities = const [],
    this.documentRevisions = const [],
  });
}
