import 'package:uuid/uuid.dart';
import '../models/ai_tool_model.dart';

abstract class AgentTool {
  String get name;
  String get description;
  bool get requiresConfirmation;

  Future<dynamic> execute(Map<String, dynamic> parameters);
}

class ReadDocumentContentTool extends AgentTool {
  final String Function() getDocumentContent;
  ReadDocumentContentTool(this.getDocumentContent);

  @override
  String get name => 'read_document_content';
  @override
  String get description => 'Reads the complete text content of the active document.';
  @override
  bool get requiresConfirmation => false;

  @override
  Future<String> execute(Map<String, dynamic> parameters) async {
    return getDocumentContent();
  }
}

class ReadSelectedTextTool extends AgentTool {
  final String? Function() getSelection;
  ReadSelectedTextTool(this.getSelection);

  @override
  String get name => 'read_selected_text';
  @override
  String get description => 'Reads the text currently selected by the user in the editor.';
  @override
  bool get requiresConfirmation => false;

  @override
  Future<String?> execute(Map<String, dynamic> parameters) async {
    return getSelection();
  }
}

class ProposeTextReplacementTool extends AgentTool {
  @override
  String get name => 'propose_text_replacement';
  @override
  String get description => 'Proposes replacing a portion of text in the document with revised content.';
  @override
  bool get requiresConfirmation => true;

  @override
  Future<AiToolProposal> execute(Map<String, dynamic> parameters) async {
    return AiToolProposal(
      id: const Uuid().v4(),
      toolName: name,
      parameters: parameters,
      targetText: parameters['targetText'] as String?,
      proposedReplacement: parameters['replacement'] as String?,
      rationale: parameters['rationale'] as String? ?? 'Suggested revision',
      status: ToolProposalStatus.pending,
      requiresConfirmation: true,
    );
  }
}

class InsertTextAtCursorTool extends AgentTool {
  @override
  String get name => 'insert_text_at_cursor';
  @override
  String get description => 'Proposes inserting generated text at the current cursor position.';
  @override
  bool get requiresConfirmation => true;

  @override
  Future<AiToolProposal> execute(Map<String, dynamic> parameters) async {
    return AiToolProposal(
      id: const Uuid().v4(),
      toolName: name,
      parameters: parameters,
      proposedReplacement: parameters['text'] as String?,
      rationale: parameters['rationale'] as String? ?? 'Insertion proposal',
      status: ToolProposalStatus.pending,
      requiresConfirmation: true,
    );
  }
}

class CreateDocumentFromPromptTool extends AgentTool {
  @override
  String get name => 'create_document_from_prompt';
  @override
  String get description => 'Proposes creating a new document draft from generated content.';
  @override
  bool get requiresConfirmation => true;

  @override
  Future<AiToolProposal> execute(Map<String, dynamic> parameters) async {
    return AiToolProposal(
      id: const Uuid().v4(),
      toolName: name,
      parameters: parameters,
      proposedReplacement: parameters['content'] as String?,
      rationale: 'Create new document "${parameters['title'] ?? 'Untitled'}"',
      status: ToolProposalStatus.pending,
      requiresConfirmation: true,
    );
  }
}
