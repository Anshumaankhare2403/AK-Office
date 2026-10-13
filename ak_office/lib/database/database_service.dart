import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../core/utilities/file_utils.dart';

class DatabaseService {
  static DatabaseService? _instance;
  static Database? _database;

  DatabaseService._internal();

  factory DatabaseService() {
    _instance ??= DatabaseService._internal();
    return _instance!;
  }

  static void initializeFfiIfRequired() {
    if (kIsWeb) return;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    initializeFfiIfRequired();

    final baseDir = await FileUtils.getAppBaseDirectory();
    final dbPath = p.join(baseDir.path, 'docucraft_storage.db');

    return await openDatabase(
      dbPath,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
        await _createTablesV1(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Migration logic for future database versions
      },
    );
  }

  Future<void> _createTablesV1(Database db) async {
    // Documents table
    await db.execute('''
      CREATE TABLE documents (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        file_path TEXT NOT NULL,
        preview_text TEXT,
        word_count INTEGER DEFAULT 0,
        character_count INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        last_opened_at INTEGER NOT NULL,
        is_pinned INTEGER DEFAULT 0,
        is_archived INTEGER DEFAULT 0,
        page_settings_json TEXT
      );
    ''');

    await db.execute('CREATE INDEX idx_documents_updated_at ON documents(updated_at DESC);');
    await db.execute('CREATE INDEX idx_documents_pinned ON documents(is_pinned DESC);');

    // Activities log table
    await db.execute('''
      CREATE TABLE activities (
        id TEXT PRIMARY KEY,
        document_id TEXT,
        document_title TEXT,
        event_type TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        description TEXT NOT NULL,
        metadata_json TEXT,
        FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE SET NULL
      );
    ''');

    await db.execute('CREATE INDEX idx_activities_timestamp ON activities(timestamp DESC);');
    await db.execute('CREATE INDEX idx_activities_doc_id ON activities(document_id);');

    // Revisions table
    await db.execute('''
      CREATE TABLE revisions (
        id TEXT PRIMARY KEY,
        document_id TEXT NOT NULL,
        version_number INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        snapshot_path TEXT NOT NULL,
        summary TEXT,
        word_count INTEGER DEFAULT 0,
        FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE
      );
    ''');

    await db.execute('CREATE INDEX idx_revisions_doc_version ON revisions(document_id, version_number DESC);');

    // AI Messages table
    await db.execute('''
      CREATE TABLE ai_messages (
        id TEXT PRIMARY KEY,
        document_id TEXT,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        proposals_json TEXT,
        FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE
      );
    ''');

    await db.execute('CREATE INDEX idx_ai_messages_doc ON ai_messages(document_id, timestamp ASC);');

    // Recovery drafts table
    await db.execute('''
      CREATE TABLE recovery_drafts (
        document_id TEXT PRIMARY KEY,
        draft_delta_json TEXT NOT NULL,
        title TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      );
    ''');
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
