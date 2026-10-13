import 'dart:convert';

enum ToolProposalStatus { pending, accepted, rejected }

class AiToolProposal {
  final String id;
  final String toolName;
  final Map<String, dynamic> parameters;
  final String? targetText;
  final String? proposedReplacement;
  final String rationale;
  final ToolProposalStatus status;
  final bool requiresConfirmation;

  AiToolProposal({
    required this.id,
    required this.toolName,
    required this.parameters,
    this.targetText,
    this.proposedReplacement,
    required this.rationale,
    this.status = ToolProposalStatus.pending,
    this.requiresConfirmation = true,
  });

  AiToolProposal copyWith({
    String? id,
    String? toolName,
    Map<String, dynamic>? parameters,
    String? targetText,
    String? proposedReplacement,
    String? rationale,
    ToolProposalStatus? status,
    bool? requiresConfirmation,
  }) {
    return AiToolProposal(
      id: id ?? this.id,
      toolName: toolName ?? this.toolName,
      parameters: parameters ?? this.parameters,
      targetText: targetText ?? this.targetText,
      proposedReplacement: proposedReplacement ?? this.proposedReplacement,
      rationale: rationale ?? this.rationale,
      status: status ?? this.status,
      requiresConfirmation: requiresConfirmation ?? this.requiresConfirmation,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tool_name': toolName,
      'parameters': parameters,
      'target_text': targetText,
      'proposed_replacement': proposedReplacement,
      'rationale': rationale,
      'status': status.name,
      'requires_confirmation': requiresConfirmation,
    };
  }

  factory AiToolProposal.fromMap(Map<String, dynamic> map) {
    return AiToolProposal(
      id: map['id'] as String,
      toolName: map['tool_name'] as String,
      parameters: map['parameters'] != null ? Map<String, dynamic>.from(map['parameters'] as Map) : {},
      targetText: map['target_text'] as String?,
      proposedReplacement: map['proposed_replacement'] as String?,
      rationale: map['rationale'] as String? ?? '',
      status: ToolProposalStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ToolProposalStatus.pending,
      ),
      requiresConfirmation: map['requires_confirmation'] as bool? ?? true,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory AiToolProposal.fromJson(String source) =>
      AiToolProposal.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
