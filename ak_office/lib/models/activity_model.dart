import 'dart:convert';

enum ActivityEventType {
  documentCreated,
  documentOpened,
  documentRenamed,
  contentChanged,
  formattingChanged,
  imageInserted,
  tableInserted,
  documentSaved,
  documentExported,
  documentImported,
  aiSuggestionAccepted,
  aiSuggestionRejected,
  versionRestored,
  documentDeleted,
}

class ActivityModel {
  final String id;
  final String? documentId;
  final String? documentTitle;
  final ActivityEventType eventType;
  final DateTime timestamp;
  final String description;
  final Map<String, dynamic> metadata;

  ActivityModel({
    required this.id,
    this.documentId,
    this.documentTitle,
    required this.eventType,
    required this.timestamp,
    required this.description,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'document_id': documentId,
      'document_title': documentTitle,
      'event_type': eventType.name,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'description': description,
      'metadata_json': jsonEncode(metadata),
    };
  }

  factory ActivityModel.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> parsedMeta = {};
    if (map['metadata_json'] != null) {
      try {
        parsedMeta = jsonDecode(map['metadata_json'] as String) as Map<String, dynamic>;
      } catch (_) {}
    }

    return ActivityModel(
      id: map['id'] as String,
      documentId: map['document_id'] as String?,
      documentTitle: map['document_title'] as String?,
      eventType: ActivityEventType.values.firstWhere(
        (e) => e.name == map['event_type'],
        orElse: () => ActivityEventType.contentChanged,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      description: map['description'] as String? ?? '',
      metadata: parsedMeta,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory ActivityModel.fromJson(String source) =>
      ActivityModel.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
