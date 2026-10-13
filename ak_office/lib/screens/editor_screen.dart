import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../ai/ai_service.dart';
import '../core/constants/app_constants.dart';
import '../core/utilities/file_utils.dart';
import '../editor/document_canvas.dart';
import '../editor/editor_controller.dart';
import '../editor/editor_toolbar.dart';
import '../editor/find_replace_bar.dart';
import '../editor/outline_panel.dart';
import '../models/activity_model.dart';
import '../models/document_model.dart';
import '../repositories/activity_repository.dart';
import '../services/document_service.dart';
import '../services/docx_service.dart';
import '../services/pdf_service.dart';
import 'assistant_panel.dart';
import 'history_screen.dart';

class EditorScreen extends StatefulWidget {
  final DocumentModel document;
  final String initialDeltaJson;

  const EditorScreen({
    super.key,
    required this.document,
    required this.initialDeltaJson,
  });

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final DocuCraftEditorController _controller;
  final DocumentService _docService = DocumentService();
  final ActivityRepository _activityRepo = ActivityRepository();
  final AiService _aiService = AiService();

  bool _isOutlineOpen = false;
  bool _isAiOpen = false;
  bool _isFindReplaceOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = DocuCraftEditorController(
      document: widget.document,
      initialDeltaJson: widget.initialDeltaJson,
      docService: _docService,
    );
  }

  Future<void> _handleSave() async {
    await _controller.save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document saved successfully.'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _handleExportDocx() async {
    try {
      final safeTitle = FileUtils.sanitizeFileName(_controller.document.title);
      final docxBytes = await DocxService.generateDocxBytes(
        deltaJson: _controller.deltaJson,
        title: _controller.document.title,
      );

      final Uri? selectedUri = await FilePicker.saveFile(
        dialogTitle: 'Export Document to Microsoft Word (.docx)',
        fileName: '$safeTitle${AppConstants.docxExtension}',
        bytes: docxBytes,
      );

      if (selectedUri == null) return;
      final selectedPath = selectedUri.scheme == 'file'
          ? selectedUri.toFilePath(windows: Platform.isWindows)
          : selectedUri.path;

      await _activityRepo.logActivity(ActivityModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        documentId: _controller.document.id,
        documentTitle: _controller.document.title,
        eventType: ActivityEventType.documentExported,
        timestamp: DateTime.now(),
        description: 'Exported document to DOCX: $selectedPath',
        metadata: {'format': 'docx', 'path': selectedPath},
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully exported DOCX to: $selectedPath')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export DOCX: $e')),
        );
      }
    }
  }

  Future<void> _handleExportPdf() async {
    try {
      final safeTitle = FileUtils.sanitizeFileName(_controller.document.title);
      final pdfBytes = await PdfService.generatePdf(
        title: _controller.document.title,
        deltaJson: _controller.deltaJson,
        pageSettings: _controller.document.pageSettings,
      );

      final Uri? selectedUri = await FilePicker.saveFile(
        dialogTitle: 'Export Document to PDF',
        fileName: '$safeTitle${AppConstants.pdfExtension}',
        bytes: pdfBytes,
      );

      if (selectedUri == null) return;
      final selectedPath = selectedUri.scheme == 'file'
          ? selectedUri.toFilePath(windows: Platform.isWindows)
          : selectedUri.path;

      await _activityRepo.logActivity(ActivityModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        documentId: _controller.document.id,
        documentTitle: _controller.document.title,
        eventType: ActivityEventType.documentExported,
        timestamp: DateTime.now(),
        description: 'Exported document to PDF: $selectedPath',
        metadata: {'format': 'pdf', 'path': selectedPath},
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully exported PDF to: $selectedPath')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export PDF: $e')),
        );
      }
    }
  }

  Future<void> _handlePrint() async {
    try {
      final pdfBytes = await PdfService.generatePdf(
        title: _controller.document.title,
        deltaJson: _controller.deltaJson,
        pageSettings: _controller.document.pageSettings,
      );
      await PdfService.printDocument(_controller.document.title, pdfBytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print preview error: $e')),
        );
      }
    }
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HistoryScreen(
          document: _controller.document,
          onVersionRestored: (newDelta) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => EditorScreen(
                  document: _controller.document,
                  initialDeltaJson: newDelta,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<bool> _promptSaveOnPop() async {
    if (!_controller.isDirty) return true;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: Text('Do you want to save changes to "${_controller.document.title}" before closing?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.wordBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save & Exit'),
          ),
        ],
      ),
    );

    if (result == 'save') {
      await _controller.save();
      return true;
    } else if (result == 'discard') {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: !_controller.isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        final shouldPop = await _promptSaveOnPop();
        if (shouldPop) {
          nav.pop();
        }
      },
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): _handleSave,
          const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
            setState(() => _isFindReplaceOpen = !_isFindReplaceOpen);
          },
          const SingleActivator(LogicalKeyboardKey.keyP, control: true): _handlePrint,
          const SingleActivator(LogicalKeyboardKey.keyB, control: true): _controller.toggleBold,
          const SingleActivator(LogicalKeyboardKey.keyI, control: true): _controller.toggleItalic,
          const SingleActivator(LogicalKeyboardKey.keyU, control: true): _controller.toggleUnderline,
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _controller.undo,
          const SingleActivator(LogicalKeyboardKey.keyY, control: true): _controller.redo,
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(42),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? const Color(0xFF383838) : const Color(0xFFE5E7EB),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 18),
                      tooltip: 'Back to Documents',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        final shouldPop = await _promptSaveOnPop();
                        if (shouldPop) {
                          nav.pop();
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppConstants.wordBlue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.description, size: 14, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _controller.document.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _controller.isDirty
                                ? Colors.orange.withValues(alpha: 0.15)
                                : Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _controller.statusMessage,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _controller.isDirty ? Colors.orange : Colors.green,
                            ),
                          ),
                        );
                      },
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.list_alt,
                        size: 18,
                        color: _isOutlineOpen ? AppConstants.wordBlue : null,
                      ),
                      tooltip: 'Toggle Outline Navigation',
                      onPressed: () => setState(() => _isOutlineOpen = !_isOutlineOpen),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.search,
                        size: 18,
                        color: _isFindReplaceOpen ? AppConstants.wordBlue : null,
                      ),
                      tooltip: 'Find and Replace (Ctrl+F)',
                      onPressed: () => setState(() => _isFindReplaceOpen = !_isFindReplaceOpen),
                    ),
                    IconButton(
                      icon: const Icon(Icons.history, size: 18),
                      tooltip: 'Revision History & Audit Log',
                      onPressed: _openHistory,
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.auto_awesome, size: 14),
                      label: const Text('AI Copilot', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isAiOpen ? AppConstants.wordDarkBlue : AppConstants.wordBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: const Size(0, 30),
                      ),
                      onPressed: () => setState(() => _isAiOpen = !_isAiOpen),
                    ),
                  ],
                ),
              ),
            ),
            body: Column(
              children: [
                DocuCraftRibbonToolbar(
                  controller: _controller,
                  onSave: _handleSave,
                  onExportDocx: _handleExportDocx,
                  onExportPdf: _handleExportPdf,
                  onPrint: _handlePrint,
                  onOpenHistory: _openHistory,
                  onToggleOutline: () => setState(() => _isOutlineOpen = !_isOutlineOpen),
                  onToggleAi: () => setState(() => _isAiOpen = !_isAiOpen),
                  isOutlineOpen: _isOutlineOpen,
                  isAiOpen: _isAiOpen,
                ),
                if (_isFindReplaceOpen)
                  FindReplaceBar(
                    controller: _controller,
                    onClose: () => setState(() => _isFindReplaceOpen = false),
                  ),
                Expanded(
                  child: Row(
                    children: [
                      if (_isOutlineOpen)
                        DocuCraftOutlinePanel(
                          controller: _controller,
                          onClose: () => setState(() => _isOutlineOpen = false),
                        ),
                      Expanded(
                        child: DocuCraftCanvas(
                          controller: _controller,
                          onToggleAi: () => setState(() => _isAiOpen = !_isAiOpen),
                          isAiOpen: _isAiOpen,
                        ),
                      ),
                      if (_isAiOpen)
                        DocuCraftAssistantPanel(
                          controller: _controller,
                          onClose: () => setState(() => _isAiOpen = false),
                          aiService: _aiService,
                          activityRepo: _activityRepo,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
