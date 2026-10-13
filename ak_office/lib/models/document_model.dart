import 'dart:convert';
import 'page_settings_model.dart';

class DocumentModel {
  final String id;
  final String title;
  final String filePath;
  final String previewText;
  final int wordCount;
  final int characterCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastOpenedAt;
  final bool isPinned;
  final bool isArchived;
  final PageSettingsModel pageSettings;

  DocumentModel({
    required this.id,
    required this.title,
    required this.filePath,
    this.previewText = '',
    this.wordCount = 0,
    this.characterCount = 0,
    required this.createdAt,
    required this.updatedAt,
    required this.lastOpenedAt,
    this.isPinned = false,
    this.isArchived = false,
    this.pageSettings = const PageSettingsModel(),
  });

  DocumentModel copyWith({
    String? id,
    String? title,
    String? filePath,
    String? previewText,
    int? wordCount,
    int? characterCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastOpenedAt,
    bool? isPinned,
    bool? isArchived,
    PageSettingsModel? pageSettings,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      previewText: previewText ?? this.previewText,
      wordCount: wordCount ?? this.wordCount,
      characterCount: characterCount ?? this.characterCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      pageSettings: pageSettings ?? this.pageSettings,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'file_path': filePath,
      'preview_text': previewText,
      'word_count': wordCount,
      'character_count': characterCount,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'last_opened_at': lastOpenedAt.millisecondsSinceEpoch,
      'is_pinned': isPinned ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
      'page_settings_json': pageSettings.toJson(),
    };
  }

  factory DocumentModel.fromMap(Map<String, dynamic> map) {
    PageSettingsModel parsedPageSettings = const PageSettingsModel();
    if (map['page_settings_json'] != null) {
      try {
        parsedPageSettings = PageSettingsModel.fromJson(map['page_settings_json'] as String);
      } catch (_) {}
    }

    return DocumentModel(
      id: map['id'] as String,
      title: map['title'] as String,
      filePath: map['file_path'] as String,
      previewText: map['preview_text'] as String? ?? '',
      wordCount: (map['word_count'] as num?)?.toInt() ?? 0,
      characterCount: (map['character_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      lastOpenedAt: DateTime.fromMillisecondsSinceEpoch(
        map['last_opened_at'] != null ? map['last_opened_at'] as int : map['updated_at'] as int,
      ),
      isPinned: (map['is_pinned'] as int?) == 1,
      isArchived: (map['is_archived'] as int?) == 1,
      pageSettings: parsedPageSettings,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory DocumentModel.fromJson(String source) =>
      DocumentModel.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
