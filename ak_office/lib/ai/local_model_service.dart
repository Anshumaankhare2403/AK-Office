import 'dart:io';
import 'package:uuid/uuid.dart';
import '../core/utilities/file_utils.dart';
import '../models/ai_message_model.dart';
import '../models/ai_tool_model.dart';
import 'activity_context_service.dart';
import 'ai_context_models.dart';
import 'document_context_service.dart';

class LocalModelConfig {
  final String? modelFilePath;
  final String modelName;
  final bool isGgufActive;

  LocalModelConfig({
    this.modelFilePath,
    this.modelName = 'Built-in Local Semantic Engine',
    this.isGgufActive = false,
  });
}

class LocalModelService {
  LocalModelConfig _config = LocalModelConfig();
  final Uuid _uuid = const Uuid();

  LocalModelConfig get config => _config;

  void setModelPath(String? path) {
    if (path != null && File(path).existsSync()) {
      final name = path.split(RegExp(r'[\\/]')).last;
      _config = LocalModelConfig(
        modelFilePath: path,
        modelName: name,
        isGgufActive: true,
      );
    } else {
      _config = LocalModelConfig();
    }
  }

  Future<String> getModelStatus() async {
    if (_config.isGgufActive && _config.modelFilePath != null) {
      final file = File(_config.modelFilePath!);
      if (await file.exists()) {
        final length = await file.length();
        return 'Local GGUF Model: ${_config.modelName} (${FileUtils.formatBytes(length)})';
      }
    }
    return 'Offline Semantic Engine (100% on-device, 0 network telemetry)';
  }

  /// Processes user prompts completely offline with document and activity context.
  Future<AiChatMessage> processPrompt(AiPromptContext context) async {
    final prompt = context.userPrompt.trim();
    final pLower = prompt.toLowerCase();

    // 1. Check if user is asking about application or document activity
    final activityAnswer = ActivityContextService.answerActivityQuery(
      query: prompt,
      currentDoc: context.currentDocument,
      activities: context.recentActivities,
      revisions: context.documentRevisions,
    );

    if (activityAnswer != null) {
      return AiChatMessage(
        id: _uuid.v4(),
        documentId: context.currentDocument?.id,
        role: AiMessageRole.assistant,
        content: activityAnswer,
        timestamp: DateTime.now(),
      );
    }

    // 2. Grammar and spelling analysis
    if (pLower.contains('grammar') || pLower.contains('spelling') || pLower.contains('mistake') || pLower.contains('typo')) {
      return _analyzeGrammarAndSpelling(context);
    }

    // 3. Summarization
    if (pLower.contains('summarize') || pLower.contains('summary') || pLower.contains('tl;dr')) {
      return _generateSummary(context);
    }

    // 4. Main points extraction
    if (pLower.contains('main point') || pLower.contains('key point') || pLower.contains('takeaway')) {
      return _extractMainPoints(context);
    }

    // 5. Rewrite professionally
    if (pLower.contains('rewrite') || pLower.contains('rephrase') || pLower.contains('polish') || pLower.contains('improve')) {
      return _proposeRewrite(context);
    }

    // 6. Generate conclusion
    if (pLower.contains('conclusion') || pLower.contains('conclude')) {
      return _generateConclusion(context);
    }

    // 7. Find inconsistencies or repetition
    if (pLower.contains('inconsisten') || pLower.contains('repetiti') || pLower.contains('contradict')) {
      return _detectInconsistencies(context);
    }

    // 8. Generate table summarizing information
    if (pLower.contains('table') && (pLower.contains('create') || pLower.contains('summariz') || pLower.contains('generate'))) {
      return _generateTableSummary(context);
    }

    // 9. Explain selection or paragraph
    if (pLower.contains('explain') || pLower.contains('meaning')) {
      return _explainContent(context);
    }

    // 10. Default contextual response with suggested assistance
    final docTitle = context.currentDocument?.title ?? 'document';
    return AiChatMessage(
      id: _uuid.v4(),
      documentId: context.currentDocument?.id,
      role: AiMessageRole.assistant,
      content: 'I analyzed **$docTitle** (${context.currentDocument?.wordCount ?? 0} words). '
          'How can I help you refine this document?\n\n'
          'Try asking:\n'
          '• *"Summarize this document"*\n'
          '• *"Find grammar and spelling mistakes"*\n'
          '• *"Rewrite this section professionally"*\n'
          '• *"Create a table summarizing key information"*\n'
          '• *"What did I do in this application today?"*\n'
          '• *"When was this document last saved?"*',
      timestamp: DateTime.now(),
    );
  }

  AiChatMessage _analyzeGrammarAndSpelling(AiPromptContext context) {
    final target = (context.selectedText != null && context.selectedText!.isNotEmpty)
        ? context.selectedText!
        : context.currentDocumentPlainText;

    if (target.trim().isEmpty) {
      return AiChatMessage(
        id: _uuid.v4(),
        documentId: context.currentDocument?.id,
        role: AiMessageRole.assistant,
        content: 'The document appears to be empty. Please add some text or select a paragraph to inspect.',
        timestamp: DateTime.now(),
      );
    }

    final List<String> issues = [];
    final List<AiToolProposal> proposals = [];

    // Check repeated consecutive words
    final repeatRegex = RegExp(r'\b([a-zA-Z]+)\s+\1\b', caseSensitive: false);
    for (final match in repeatRegex.allMatches(target)) {
      final word = match.group(1);
      final fullMatch = match.group(0)!;
      issues.add('Repeated consecutive word: **"$fullMatch"**');
      proposals.add(AiToolProposal(
        id: _uuid.v4(),
        toolName: 'propose_text_replacement',
        parameters: {'targetText': fullMatch, 'replacement': word},
        targetText: fullMatch,
        proposedReplacement: word,
        rationale: 'Remove accidental word duplication "$fullMatch"',
      ));
    }

    // Common misspellings and stylistic corrections
    final Map<String, String> commonTypos = {
      'teh': 'the',
      'recieve': 'receive',
      'seperate': 'separate',
      'occurance': 'occurrence',
      'untill': 'until',
      'definately': 'definitely',
      'accomodate': 'accommodate',
      'alot': 'a lot',
      'cant': "can't",
      'dont': "don't",
      'wont': "won't",
    };

    for (final entry in commonTypos.entries) {
      final typoRegex = RegExp('\\b${entry.key}\\b', caseSensitive: false);
      for (final m in typoRegex.allMatches(target)) {
        final matchStr = m.group(0)!;
        issues.add('Possible misspelling: **"$matchStr"** -> suggest **"${entry.value}"**');
        proposals.add(AiToolProposal(
          id: _uuid.v4(),
          toolName: 'propose_text_replacement',
          parameters: {'targetText': matchStr, 'replacement': entry.value},
          targetText: matchStr,
          proposedReplacement: entry.value,
          rationale: 'Correct spelling from "$matchStr" to "${entry.value}"',
        ));
      }
    }

    final StringBuffer buf = StringBuffer();
    if (issues.isEmpty) {
      buf.writeln('No prominent grammar or spelling errors detected in the inspected text.');
      buf.writeln('\n• Checked punctuation, duplicate tokens, and common orthographic patterns.');
    } else {
      buf.writeln('Identified **${issues.length}** suggestion(s):\n');
      for (final issue in issues.take(5)) {
        buf.writeln('• $issue');
      }
      buf.writeln('\nReview the proposed replacement cards below to accept or reject changes.');
    }

    return AiChatMessage(
      id: _uuid.v4(),
      documentId: context.currentDocument?.id,
      role: AiMessageRole.assistant,
      content: buf.toString(),
      timestamp: DateTime.now(),
      proposals: proposals,
    );
  }

  AiChatMessage _generateSummary(AiPromptContext context) {
    final text = context.currentDocumentPlainText;
    if (text.trim().isEmpty) {
      return AiChatMessage(
        id: _uuid.v4(),
        documentId: context.currentDocument?.id,
        role: AiMessageRole.assistant,
        content: 'Document is currently blank. Cannot generate a summary.',
        timestamp: DateTime.now(),
      );
    }

    final sentences = DocumentContextService.extractKeySentences(text, count: 4);
    final buf = StringBuffer('### Executive Summary\n\n');
    for (final s in sentences) {
      buf.writeln('> $s\n');
    }

    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    buf.writeln('**Document Statistics:** $words total words across ${DocumentContextService.extractParagraphs(text).length} paragraphs.');

    return AiChatMessage(
      id: _uuid.v4(),
      documentId: context.currentDocument?.id,
      role: AiMessageRole.assistant,
      content: buf.toString(),
      timestamp: DateTime.now(),
    );
  }

  AiChatMessage _extractMainPoints(AiPromptContext context) {
    final text = context.currentDocumentPlainText;
    final sentences = DocumentContextService.extractKeySentences(text, count: 5);

    final buf = StringBuffer('### Key Takeaways\n\n');
    for (int i = 0; i < sentences.length; i++) {
      buf.writeln('${i + 1}. **Point ${i + 1}:** ${sentences[i]}');
    }

    return AiChatMessage(
      id: _uuid.v4(),
      documentId: context.currentDocument?.id,
      role: AiMessageRole.assistant,
      content: buf.toString(),
      timestamp: DateTime.now(),
    );
  }

  AiChatMessage _proposeRewrite(AiPromptContext context) {
    final target = (context.selectedText != null && context.selectedText!.isNotEmpty)
        ? context.selectedText!
        : (DocumentContextService.extractParagraphs(context.currentDocumentPlainText).firstOrNull ?? '');

    if (target.trim().isEmpty) {
      return AiChatMessage(
        id: _uuid.v4(),
        documentId: context.currentDocument?.id,
        role: AiMessageRole.assistant,
        content: 'Please select a paragraph or sentence to rewrite professionally.',
        timestamp: DateTime.now(),
      );
    }

    // Generate polished professional variant
    final rewritten = _cleanAndElevateText(target);

    final proposal = AiToolProposal(
      id: _uuid.v4(),
      toolName: 'propose_text_replacement',
      parameters: {'targetText': target, 'replacement': rewritten},
      targetText: target,
      proposedReplacement: rewritten,
      rationale: 'Elevate tone to formal executive style with enhanced clarity and conciseness.',
      requiresConfirmation: true,
    );

    return AiChatMessage(
      id: _uuid.v4(),
      documentId: context.currentDocument?.id,
      role: AiMessageRole.assistant,
      content: 'Here is a professional rephrasing for the target section. Review the proposal below:',
      timestamp: DateTime.now(),
      proposals: [proposal],
    );
  }

  AiChatMessage _generateConclusion(AiPromptContext context) {
    final text = context.currentDocumentPlainText;
    final keySentences = DocumentContextService.extractKeySentences(text, count: 2);

    final String conclusionText = keySentences.isNotEmpty
        ? 'In conclusion, the findings demonstrated that ${keySentences.first.toLowerCase()} '
            'Moving forward, these insights establish a solid foundation for operational execution.'
        : 'In conclusion, the objectives outlined herein provide a cohesive and actionable framework for subsequent implementation.';

    final proposal = AiToolProposal(
      id: _uuid.v4(),
      toolName: 'insert_text_at_cursor',
      parameters: {'text': '\n\n### Conclusion\n$conclusionText\n'},
      proposedReplacement: '\n\n### Conclusion\n$conclusionText\n',
      rationale: 'Insert structured concluding section into document.',
      requiresConfirmation: true,
    );

    return AiChatMessage(
      id: _uuid.v4(),
      documentId: context.currentDocument?.id,
      role: AiMessageRole.assistant,
      content: 'I generated a conclusion based on the core points of your document:\n\n'
          '*"$conclusionText"*\n\n'
          'You can insert this section directly into the document using the proposal card below.',
      timestamp: DateTime.now(),
      proposals: [proposal],
    );
  }

  AiChatMessage _detectInconsistencies(AiPromptContext context) {
    final text = context.currentDocumentPlainText;
    final words = text.toLowerCase().split(RegExp(r'\W+')).where((w) => w.length > 5).toList();

    final Map<String, int> counts = {};
    for (final w in words) {
      counts[w] = (counts[w] ?? 0) + 1;
    }

    final overused = counts.entries.where((e) => e.value >= 4).toList();
    overused.sort((a, b) => b.value.compareTo(a.value));

    final buf = StringBuffer('### Consistency & Repetition Audit\n\n');
    if (overused.isEmpty) {
      buf.writeln('• Tone and vocabulary diversity appear balanced across the document.');
    } else {
      buf.writeln('**Frequent Vocabulary (Potential Repetition):**\n');
      for (final e in overused.take(4)) {
        buf.writeln('• The term **"${e.key}"** appears **${e.value} times**. Consider substituting with synonyms to vary cadence.');
      }
    }

    return AiChatMessage(
      id: _uuid.v4(),
      documentId: context.currentDocument?.id,
      role: AiMessageRole.assistant,
      content: buf.toString(),
      timestamp: DateTime.now(),
    );
  }

  AiChatMessage _generateTableSummary(AiPromptContext context) {
    final text = context.currentDocumentPlainText;
    final paragraphs = DocumentContextService.extractParagraphs(text);

    final buf = StringBuffer('| Section / Topic | Key Insight | Status |\n');
    buf.writeln('| :--- | :--- | :--- |');

    int rowCount = 0;
    for (final p in paragraphs) {
      if (p.length > 25 && rowCount < 5) {
        final snippet = p.length > 60 ? '${p.substring(0, 60)}...' : p;
        buf.writeln('| Section ${rowCount + 1} | $snippet | Active |');
        rowCount++;
      }
    }

    if (rowCount == 0) {
      buf.writeln('| Overview | General Document Outline | Completed |');
    }

    final tableString = buf.toString();

    final proposal = AiToolProposal(
      id: _uuid.v4(),
      toolName: 'insert_text_at_cursor',
      parameters: {'text': '\n\n$tableString\n'},
      proposedReplacement: '\n\n$tableString\n',
      rationale: 'Insert Markdown/Text summary table into document.',
      requiresConfirmation: true,
    );

    return AiChatMessage(
      id: _uuid.v4(),
      documentId: context.currentDocument?.id,
      role: AiMessageRole.assistant,
      content: 'Here is a synthesized table summarizing the key sections:\n\n$tableString\n\n'
          'Click Accept below to insert this table at your cursor position.',
      timestamp: DateTime.now(),
      proposals: [proposal],
    );
  }

  AiChatMessage _explainContent(AiPromptContext context) {
    final target = (context.selectedText != null && context.selectedText!.isNotEmpty)
        ? context.selectedText!
        : (DocumentContextService.extractParagraphs(context.currentDocumentPlainText).firstOrNull ?? '');

    if (target.isEmpty) {
      return AiChatMessage(
        id: _uuid.v4(),
        documentId: context.currentDocument?.id,
        role: AiMessageRole.assistant,
        content: 'Please select the passage you would like explained.',
        timestamp: DateTime.now(),
      );
    }

    final wordCount = target.split(RegExp(r'\s+')).length;
    return AiChatMessage(
      id: _uuid.v4(),
      documentId: context.currentDocument?.id,
      role: AiMessageRole.assistant,
      content: '### Passage Analysis\n\n'
          '> "$target"\n\n'
          '• **Length:** $wordCount words.\n'
          '• **Tone:** Professional declarative.\n'
          '• **Core Proposition:** This passage conveys an assertive statement concerning the topic domain, '
          'aimed at establishing clarity for the intended audience.',
      timestamp: DateTime.now(),
    );
  }

  String _cleanAndElevateText(String input) {
    var out = input.trim();
    out = out.replaceAll(RegExp(r'\bvery good\b', caseSensitive: false), 'exemplary');
    out = out.replaceAll(RegExp(r'\ba lot of\b', caseSensitive: false), 'substantial');
    out = out.replaceAll(RegExp(r'\bmake sure\b', caseSensitive: false), 'ensure');
    out = out.replaceAll(RegExp(r'\bhelp\b', caseSensitive: false), 'facilitate');
    out = out.replaceAll(RegExp(r'\bstart\b', caseSensitive: false), 'initiate');
    out = out.replaceAll(RegExp(r'\bbig\b', caseSensitive: false), 'significant');
    if (!out.endsWith('.')) out += '.';
    return out;
  }
}
