import 'package:sqflite/sqflite.dart';
import '../database/database_service.dart';
import '../models/activity_model.dart';

class ActivityRepository {
  final DatabaseService _dbService;

  ActivityRepository({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService();

  Future<void> logActivity(ActivityModel activity) async {
    final db = await _dbService.database;
    await db.insert(
      'activities',
      activity.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ActivityModel>> getAllActivities({int limit = 100}) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'activities',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return maps.map((m) => ActivityModel.fromMap(m)).toList();
  }

  Future<List<ActivityModel>> getActivitiesForDocument(String documentId, {int limit = 50}) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'activities',
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return maps.map((m) => ActivityModel.fromMap(m)).toList();
  }

  Future<List<ActivityModel>> getActivitiesToday() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'activities',
      where: 'timestamp >= ?',
      whereArgs: [startOfDay],
      orderBy: 'timestamp DESC',
    );
    return maps.map((m) => ActivityModel.fromMap(m)).toList();
  }

  Future<List<ActivityModel>> searchActivities(String query, {int limit = 50}) async {
    final db = await _dbService.database;
    final sanitizedQuery = '%${query.trim()}%';
    final List<Map<String, dynamic>> maps = await db.query(
      'activities',
      where: 'description LIKE ? OR document_title LIKE ? OR event_type LIKE ?',
      whereArgs: [sanitizedQuery, sanitizedQuery, sanitizedQuery],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return maps.map((m) => ActivityModel.fromMap(m)).toList();
  }

  Future<void> clearActivities({String? documentId}) async {
    final db = await _dbService.database;
    if (documentId != null) {
      await db.delete(
        'activities',
        where: 'document_id = ?',
        whereArgs: [documentId],
      );
    } else {
      await db.delete('activities');
    }
  }
}
