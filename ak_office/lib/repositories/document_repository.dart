import 'package:sqflite/sqflite.dart';
import '../database/database_service.dart';
import '../models/document_model.dart';

class DocumentRepository {
  final DatabaseService _dbService;

  DocumentRepository({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService();

  Future<void> createDocument(DocumentModel document) async {
    final db = await _dbService.database;
    await db.insert(
      'documents',
      document.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateDocument(DocumentModel document) async {
    final db = await _dbService.database;
    await db.update(
      'documents',
      document.toMap(),
      where: 'id = ?',
      whereArgs: [document.id],
    );
  }

  Future<DocumentModel?> getDocumentById(String id) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'documents',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return DocumentModel.fromMap(maps.first);
  }

  Future<List<DocumentModel>> getAllDocuments({bool includeArchived = false}) async {
    final db = await _dbService.database;
    final String whereClause = includeArchived ? '' : 'is_archived = 0';
    final List<Map<String, dynamic>> maps = await db.query(
      'documents',
      where: whereClause.isEmpty ? null : whereClause,
      orderBy: 'is_pinned DESC, updated_at DESC',
    );
    return maps.map((m) => DocumentModel.fromMap(m)).toList();
  }

  Future<List<DocumentModel>> getRecentDocuments({int limit = 10}) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'documents',
      where: 'is_archived = 0',
      orderBy: 'last_opened_at DESC',
      limit: limit,
    );
    return maps.map((m) => DocumentModel.fromMap(m)).toList();
  }

  Future<List<DocumentModel>> searchDocuments(String query) async {
    if (query.trim().isEmpty) {
      return getAllDocuments();
    }
    final db = await _dbService.database;
    final sanitizedQuery = '%${query.trim()}%';
    final List<Map<String, dynamic>> maps = await db.query(
      'documents',
      where: '(title LIKE ? OR preview_text LIKE ?) AND is_archived = 0',
      whereArgs: [sanitizedQuery, sanitizedQuery],
      orderBy: 'updated_at DESC',
    );
    return maps.map((m) => DocumentModel.fromMap(m)).toList();
  }

  Future<void> togglePin(String id, bool isPinned) async {
    final db = await _dbService.database;
    await db.update(
      'documents',
      {'is_pinned': isPinned ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> toggleArchive(String id, bool isArchived) async {
    final db = await _dbService.database;
    await db.update(
      'documents',
      {'is_archived': isArchived ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateLastOpened(String id) async {
    final db = await _dbService.database;
    await db.update(
      'documents',
      {'last_opened_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteDocument(String id) async {
    final db = await _dbService.database;
    await db.delete(
      'documents',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
