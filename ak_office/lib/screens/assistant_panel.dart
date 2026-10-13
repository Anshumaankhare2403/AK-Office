import 'package:flutter/material.dart';
import '../ai/ai_context_models.dart';
import '../ai/ai_service.dart';
import '../core/constants/app_constants.dart';
import '../core/utilities/diff_utils.dart';
import '../editor/editor_controller.dart';
import '../models/ai_message_model.dart';
import '../models/ai_tool_model.dart';
import '../repositories/activity_repository.dart';
import '../repositories/revision_repository.dart';

class DocuCraftAssistantPanel extends StatefulWidget {
  final DocuCraftEditorController controller;
  final VoidCallback onClose;
  final AiService? aiService;
  final ActivityRepository? activityRepo;
  final RevisionRepository? revisionRepo;

  const DocuCraftAssistantPanel({
    super.key,
    required this.controller,
    required this.onClose,
    this.aiService,
    this.activityRepo,
    this.revisionRepo,
  });

  @override
  State<DocuCraftAssistantPanel> createState() => _DocuCraftAssistantPanelState();
}

class _DocuCraftAssistantPanelState extends State<DocuCraftAssistantPanel> {
  late final AiService _aiService;
  late final ActivityRepository _activityRepo;
  late final RevisionRepository _revisionRepo;
  final TextEditingController _promptCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<AiChatMessage> _messages = [];
  bool _isLoading = false;
  String _engineStatus = 'Offline Local Engine';

  @override
  void initState() {
    super.initState();
    _aiService = widget.aiService ?? AiService();
    _activityRepo = widget.activityRepo ?? ActivityRepository();
    _revisionRepo = widget.revisionRepo ?? RevisionRepository();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final status = await _aiService.getEngineStatus();
    final history = await _aiService.getChatHistory(widget.controller.document.id);

    if (mounted) {
      setState(() {
        _engineStatus = status;
        _messages = history;
      });

      if (_messages.isEmpty) {
        _addWelcomeMessage();
      }
      _scrollToBottom();
    }
  }

  void _addWelcomeMessage() {
    setState(() {
      _messages.add(AiChatMessage(
        id: 'welcome',
        documentId: widget.controller.document.id,
        role: AiMessageRole.assistant,
        content: 'Hello! I am your **DocuCraft Assistant**, operating entirely on your local machine with 0 external network requests.\n\n'
            'I can inspect your document, suggest professional rewrites, correct grammar, generate summaries, and audit your activity.',
        timestamp: DateTime.now(),
      ));
    });
  }

  Future<void> _submitPrompt([String? explicitPrompt]) async {
    final prompt = explicitPrompt ?? _promptCtrl.text.trim();
    if (prompt.isEmpty || _isLoading) return;

    if (explicitPrompt == null) {
      _promptCtrl.clear();
    }

    final userMsg = AiChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      documentId: widget.controller.document.id,
      role: AiMessageRole.user,
      content: prompt,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final activities = await _activityRepo.getAllActivities(limit: 50);
      final revisions = await _revisionRepo.getRevisionsForDocument(widget.controller.document.id);

      final context = AiPromptContext(
        userPrompt: prompt,
        currentDocument: widget.controller.document,
        currentDocumentPlainText: widget.controller.plainText,
        selectedText: widget.controller.selectedText,
        cursorPosition: widget.controller.cursorOffset,
        recentActivities: activities,
        documentRevisions: revisions,
      );

      final response = await _aiService.askAssistant(context);

      if (mounted) {
        setState(() {
          _messages.add(response);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(AiChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            documentId: widget.controller.document.id,
            role: AiMessageRole.assistant,
            content: 'An error occurred during local processing: $e',
            timestamp: DateTime.now(),
          ));
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleAcceptProposal(AiToolProposal proposal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Document Modification'),
        content: Text(
          'Do you want to apply the following action to your document?\n\n'
          '"${proposal.rationale}"',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.wordBlue, foregroundColor: Colors.white),
            child: const Text('Apply Changes'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (proposal.toolName == 'propose_text_replacement') {
      if (proposal.targetText != null && proposal.proposedReplacement != null) {
        final success = widget.controller.replaceTargetText(
          proposal.targetText!,
          proposal.proposedReplacement!,
        );
        if (!success) {
          widget.controller.replaceSelection(proposal.proposedReplacement!);
        }
      }
    } else if (proposal.toolName == 'insert_text_at_cursor') {
      if (proposal.proposedReplacement != null) {
        widget.controller.insertTextAtCursor(proposal.proposedReplacement!);
      }
    }

    await _aiService.logProposalAccepted(widget.controller.document, proposal);

    if (mounted) {
      setState(() {
        final updatedProposal = proposal.copyWith(status: ToolProposalStatus.accepted);
        _updateProposalInMessages(updatedProposal);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI changes successfully applied to document.')),
      );
    }
  }

  Future<void> _handleRejectProposal(AiToolProposal proposal) async {
    await _aiService.logProposalRejected(widget.controller.document, proposal);
    if (mounted) {
      setState(() {
        final updatedProposal = proposal.copyWith(status: ToolProposalStatus.rejected);
        _updateProposalInMessages(updatedProposal);
      });
    }
  }

  void _updateProposalInMessages(AiToolProposal proposal) {
    for (int i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      final pIndex = m.proposals.indexWhere((p) => p.id == proposal.id);
      if (pIndex != -1) {
        final updatedList = List<AiToolProposal>.from(m.proposals);
        updatedList[pIndex] = proposal;
        _messages[i] = m.copyWith(proposals: updatedList);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF222222) : const Color(0xFFF9FAFB),
        border: Border(
          left: BorderSide(
            color: isDark ? const Color(0xFF383838) : const Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(isDark),
          _buildQuickActionChips(isDark),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageItem(msg, isDark);
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppConstants.wordBlue),
                  ),
                  SizedBox(width: 8),
                  Text('Analyzing locally...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          _buildInputBar(isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF383838) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 18, color: AppConstants.wordBlue),
              const SizedBox(width: 8),
              const Text(
                'DocuCraft Assistant',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 16),
                tooltip: 'Clear Conversation',
                onPressed: () async {
                  await _aiService.clearChatHistory(widget.controller.document.id);
                  if (mounted) {
                    setState(() => _messages = []);
                    _addWelcomeMessage();
                  }
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                tooltip: 'Close AI Assistant',
                onPressed: widget.onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 11, color: Colors.green),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _engineStatus,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionChips(bool isDark) {
    final chips = [
      'Summarize this document',
      'Find grammar and spelling mistakes',
      'What are the main points?',
      'Rewrite this section professionally',
      'Generate a conclusion',
      'Create a table summarizing key information',
      'What did I do in this application today?',
      'When was this document last saved?',
    ];

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF303030) : const Color(0xFFEFF1F4),
          ),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: chips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final text = chips[index];
          return ActionChip(
            label: Text(text, style: const TextStyle(fontSize: 10)),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onPressed: () => _submitPrompt(text),
          );
        },
      ),
    );
  }

  Widget _buildMessageItem(AiChatMessage msg, bool isDark) {
    final isUser = msg.role == AiMessageRole.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isUser ? Icons.person : Icons.auto_awesome,
                size: 12,
                color: isUser ? Colors.grey : AppConstants.wordBlue,
              ),
              const SizedBox(width: 4),
              Text(
                isUser ? 'You' : 'DocuCraft Assistant',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isUser
                  ? AppConstants.wordBlue
                  : (isDark ? const Color(0xFF2C2C2C) : Colors.white),
              borderRadius: BorderRadius.circular(8),
              border: !isUser && !isDark
                  ? Border.all(color: const Color(0xFFE2E4E8))
                  : null,
            ),
            child: SelectableText(
              msg.content,
              style: TextStyle(
                fontSize: 12,
                color: isUser ? Colors.white : (isDark ? Colors.white : AppConstants.textPrimaryLight),
                height: 1.4,
              ),
            ),
          ),
          if (msg.proposals.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...msg.proposals.map((p) => _buildProposalCard(p, isDark)),
          ],
        ],
      ),
    );
  }

  Widget _buildProposalCard(AiToolProposal proposal, bool isDark) {
    final isPending = proposal.status == ToolProposalStatus.pending;
    final isAccepted = proposal.status == ToolProposalStatus.accepted;

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF282828) : const Color(0xFFF3F7FA),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isAccepted
              ? Colors.green
              : (proposal.status == ToolProposalStatus.rejected
                  ? Colors.red.withValues(alpha: 0.5)
                  : AppConstants.wordBlue.withValues(alpha: 0.5)),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isAccepted
                    ? Icons.check_circle
                    : (proposal.status == ToolProposalStatus.rejected
                        ? Icons.cancel
                        : Icons.edit_note),
                size: 16,
                color: isAccepted
                    ? Colors.green
                    : (proposal.status == ToolProposalStatus.rejected
                        ? Colors.red
                        : AppConstants.wordBlue),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  proposal.rationale,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              if (!isPending)
                Text(
                  proposal.status.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isAccepted ? Colors.green : Colors.red,
                  ),
                ),
            ],
          ),
          if (proposal.targetText != null && proposal.proposedReplacement != null) ...[
            const SizedBox(height: 6),
            _buildDiffWidget(proposal.targetText!, proposal.proposedReplacement!, isDark),
          ] else if (proposal.proposedReplacement != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                proposal.proposedReplacement!,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _handleRejectProposal(proposal),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(60, 28),
                  ),
                  child: const Text('Reject', style: TextStyle(fontSize: 11)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _handleAcceptProposal(proposal),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.wordBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: const Size(70, 28),
                  ),
                  child: const Text('Accept', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDiffWidget(String original, String modified, bool isDark) {
    final diffSegments = DiffUtils.computeWordDiff(original, modified);

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white70 : AppConstants.textPrimaryLight,
          ),
          children: diffSegments.map((seg) {
            if (seg.type == DiffType.deletion) {
              return TextSpan(
                text: seg.text,
                style: const TextStyle(
                  backgroundColor: Color(0xFFFFD1D1),
                  color: Colors.red,
                  decoration: TextDecoration.lineThrough,
                ),
              );
            } else if (seg.type == DiffType.insertion) {
              return TextSpan(
                text: seg.text,
                style: const TextStyle(
                  backgroundColor: Color(0xFFD4EDDA),
                  color: Color(0xFF155724),
                  fontWeight: FontWeight.bold,
                ),
              );
            }
            return TextSpan(text: seg.text);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInputBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF383838) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _promptCtrl,
              style: const TextStyle(fontSize: 12),
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                hintText: 'Ask AI about this document...',
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              onSubmitted: (_) => _submitPrompt(),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.send, size: 18, color: AppConstants.wordBlue),
            onPressed: () => _submitPrompt(),
            tooltip: 'Send prompt',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
