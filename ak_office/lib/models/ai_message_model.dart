import 'dart:convert';
import 'ai_tool_model.dart';

enum AiMessageRole { user, assistant, system }

class AiChatMessage {
  final String id;
  final String? documentId;
  final AiMessageRole role;
  final String content;
  final DateTime timestamp;
  final List<AiToolProposal> proposals;
  final bool isGenerating;

  AiChatMessage({
    required this.id,
    this.documentId,
    required this.role,
    required this.content,
    required this.timestamp,
    this.proposals = const [],
    this.isGenerating = false,
  });

  AiChatMessage copyWith({
    String? id,
    String? documentId,
    AiMessageRole? role,
    String? content,
    DateTime? timestamp,
    List<AiToolProposal>? proposals,
    bool? isGenerating,
  }) {
    return AiChatMessage(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      proposals: proposals ?? this.proposals,
      isGenerating: isGenerating ?? this.isGenerating,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'document_id': documentId,
      'role': role.name,
      'content': content,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'proposals_json': jsonEncode(proposals.map((p) => p.toMap()).toList()),
    };
  }

  factory AiChatMessage.fromMap(Map<String, dynamic> map) {
    List<AiToolProposal> parsedProposals = [];
    if (map['proposals_json'] != null) {
      try {
        final list = jsonDecode(map['proposals_json'] as String) as List;
        parsedProposals = list.map((item) => AiToolProposal.fromMap(item as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    return AiChatMessage(
      id: map['id'] as String,
      documentId: map['document_id'] as String?,
      role: AiMessageRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => AiMessageRole.assistant,
      ),
      content: map['content'] as String? ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      proposals: parsedProposals,
      isGenerating: false,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory AiChatMessage.fromJson(String source) =>
      AiChatMessage.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
