import 'dart:convert';

class RevisionModel {
  final String id;
  final String documentId;
  final int versionNumber;
  final DateTime timestamp;
  final String snapshotPath;
  final String summary;
  final int wordCount;

  RevisionModel({
    required this.id,
    required this.documentId,
    required this.versionNumber,
    required this.timestamp,
    required this.snapshotPath,
    required this.summary,
    required this.wordCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'document_id': documentId,
      'version_number': versionNumber,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'snapshot_path': snapshotPath,
      'summary': summary,
      'word_count': wordCount,
    };
  }

  factory RevisionModel.fromMap(Map<String, dynamic> map) {
    return RevisionModel(
      id: map['id'] as String,
      documentId: map['document_id'] as String,
      versionNumber: (map['version_number'] as num).toInt(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      snapshotPath: map['snapshot_path'] as String,
      summary: map['summary'] as String? ?? 'Revision',
      wordCount: (map['word_count'] as num?)?.toInt() ?? 0,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory RevisionModel.fromJson(String source) =>
      RevisionModel.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
