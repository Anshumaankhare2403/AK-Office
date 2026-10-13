import 'package:sqflite/sqflite.dart';
import '../database/database_service.dart';

class RecoveryDraft {
  final String documentId;
  final String title;
  final String draftDeltaJson;
  final DateTime timestamp;

  RecoveryDraft({
    required this.documentId,
    required this.title,
    required this.draftDeltaJson,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'document_id': documentId,
      'title': title,
      'draft_delta_json': draftDeltaJson,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory RecoveryDraft.fromMap(Map<String, dynamic> map) {
    return RecoveryDraft(
      documentId: map['document_id'] as String,
      title: map['title'] as String,
      draftDeltaJson: map['draft_delta_json'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class RecoveryRepository {
  final DatabaseService _dbService;

  RecoveryRepository({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService();

  Future<void> saveDraft(String documentId, String title, String deltaJson) async {
    final db = await _dbService.database;
    await db.insert(
      'recovery_drafts',
      {
        'document_id': documentId,
        'title': title,
        'draft_delta_json': deltaJson,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<RecoveryDraft?> getDraft(String documentId) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'recovery_drafts',
      where: 'document_id = ?',
      whereArgs: [documentId],
    );
    if (maps.isEmpty) return null;
    return RecoveryDraft.fromMap(maps.first);
  }

  Future<List<RecoveryDraft>> getAllDrafts() async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'recovery_drafts',
      orderBy: 'timestamp DESC',
    );
    return maps.map((m) => RecoveryDraft.fromMap(m)).toList();
  }

  Future<void> deleteDraft(String documentId) async {
    final db = await _dbService.database;
    await db.delete(
      'recovery_drafts',
      where: 'document_id = ?',
      whereArgs: [documentId],
    );
  }
}
