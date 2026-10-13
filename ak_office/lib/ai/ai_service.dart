import 'package:uuid/uuid.dart';
import '../database/database_service.dart';
import '../models/activity_model.dart';
import '../models/ai_message_model.dart';
import '../models/ai_tool_model.dart';
import '../models/document_model.dart';
import '../repositories/activity_repository.dart';
import 'ai_context_models.dart';
import 'local_model_service.dart';

class AiService {
  final LocalModelService _localModel;
  final ActivityRepository _activityRepo;
  final DatabaseService _dbService;
  final Uuid _uuid;

  AiService({
    LocalModelService? localModel,
    ActivityRepository? activityRepo,
    DatabaseService? dbService,
  })  : _localModel = localModel ?? LocalModelService(),
        _activityRepo = activityRepo ?? ActivityRepository(),
        _dbService = dbService ?? DatabaseService(),
        _uuid = const Uuid();

  LocalModelService get localModel => _localModel;

  Future<String> getEngineStatus() async {
    return await _localModel.getModelStatus();
  }

  /// Sends user prompt to local model and records message in SQLite.
  Future<AiChatMessage> askAssistant(AiPromptContext context) async {
    // 1. Record user message
    final userMsg = AiChatMessage(
      id: _uuid.v4(),
      documentId: context.currentDocument?.id,
      role: AiMessageRole.user,
      content: context.userPrompt,
      timestamp: DateTime.now(),
    );
    await _saveMessage(userMsg);

    // 2. Process with offline model
    final assistantMsg = await _localModel.processPrompt(context);
    await _saveMessage(assistantMsg);

    return assistantMsg;
  }

  /// Retrieves persistent chat history for the document.
  Future<List<AiChatMessage>> getChatHistory(String? documentId) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'ai_messages',
      where: documentId != null ? 'document_id = ?' : 'document_id IS NULL',
      whereArgs: documentId != null ? [documentId] : null,
      orderBy: 'timestamp ASC',
      limit: 50,
    );
    return maps.map((m) => AiChatMessage.fromMap(m)).toList();
  }

  /// Clears chat history for document.
  Future<void> clearChatHistory(String? documentId) async {
    final db = await _dbService.database;
    if (documentId != null) {
      await db.delete('ai_messages', where: 'document_id = ?', whereArgs: [documentId]);
    } else {
      await db.delete('ai_messages');
    }
  }

  /// User explicitly accepted an AI proposal.
  Future<void> logProposalAccepted(DocumentModel? doc, AiToolProposal proposal) async {
    await _activityRepo.logActivity(ActivityModel(
      id: _uuid.v4(),
      documentId: doc?.id,
      documentTitle: doc?.title,
      eventType: ActivityEventType.aiSuggestionAccepted,
      timestamp: DateTime.now(),
      description: 'Accepted AI proposal: ${proposal.rationale}',
      metadata: proposal.toMap(),
    ));
  }

  /// User rejected an AI proposal.
  Future<void> logProposalRejected(DocumentModel? doc, AiToolProposal proposal) async {
    await _activityRepo.logActivity(ActivityModel(
      id: _uuid.v4(),
      documentId: doc?.id,
      documentTitle: doc?.title,
      eventType: ActivityEventType.aiSuggestionRejected,
      timestamp: DateTime.now(),
      description: 'Rejected AI proposal: ${proposal.rationale}',
      metadata: proposal.toMap(),
    ));
  }

  Future<void> _saveMessage(AiChatMessage msg) async {
    try {
      final db = await _dbService.database;
      await db.insert('ai_messages', msg.toMap());
    } catch (_) {}
  }
}
