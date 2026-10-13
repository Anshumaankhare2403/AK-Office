import 'package:sqflite/sqflite.dart';
import '../database/database_service.dart';
import '../models/revision_model.dart';

class RevisionRepository {
  final DatabaseService _dbService;

  RevisionRepository({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService();

  Future<void> saveRevision(RevisionModel revision) async {
    final db = await _dbService.database;
    await db.insert(
      'revisions',
      revision.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<RevisionModel>> getRevisionsForDocument(String documentId) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'revisions',
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'version_number DESC',
    );
    return maps.map((m) => RevisionModel.fromMap(m)).toList();
  }

  Future<RevisionModel?> getRevisionById(String id) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'revisions',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return RevisionModel.fromMap(maps.first);
  }

  Future<RevisionModel?> getLatestRevision(String documentId) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'revisions',
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'version_number DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return RevisionModel.fromMap(maps.first);
  }

  Future<void> deleteRevisionsForDocument(String documentId) async {
    final db = await _dbService.database;
    await db.delete(
      'revisions',
      where: 'document_id = ?',
      whereArgs: [documentId],
    );
  }
}
