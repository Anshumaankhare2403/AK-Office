import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_constants.dart';
import '../models/document_model.dart';
import '../repositories/document_repository.dart';
import '../services/document_service.dart';
import '../services/docx_service.dart';
import '../services/recovery_service.dart';
import 'editor_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DocumentRepository _docRepo = DocumentRepository();
  final DocumentService _docService = DocumentService();
  final RecoveryService _recoveryService = RecoveryService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<DocumentModel> _documents = [];
  List<RecoverableDocument> _recoverableDrafts = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDocuments();
    _checkCrashRecovery();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    final docs = _searchQuery.isEmpty
        ? await _docRepo.getAllDocuments()
        : await _docRepo.searchDocuments(_searchQuery);
    setState(() {
      _documents = docs;
      _isLoading = false;
    });
  }

  Future<void> _checkCrashRecovery() async {
    try {
      final drafts = await _recoveryService.checkForRecoverableDrafts();
      if (drafts.isNotEmpty && mounted) {
        setState(() => _recoverableDrafts = drafts);
      }
    } catch (_) {}
  }

  Future<void> _createNewDocument({
    String title = 'Untitled Document',
    String? initialContent,
  }) async {
    try {
      final doc = await _docService.createNewDocument(
        title: title,
        initialContentJson: initialContent,
      );
      if (mounted) {
        _openDocument(doc);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create document: $e')),
        );
      }
    }
  }

  Future<void> _openDocument(DocumentModel doc) async {
    try {
      final deltaJson = await _docService.loadDocumentContent(doc);
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EditorScreen(
              document: doc,
              initialDeltaJson: deltaJson,
            ),
          ),
        );
        _loadDocuments();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open document: $e')),
        );
      }
    }
  }

  Future<void> _importDocxFile() async {
    try {
      final files = await FilePicker.pickFiles(
        dialogTitle: 'Select Microsoft Word (.docx) Document',
        type: FileType.custom,
        allowedExtensions: ['docx'],
      );

      if (files.isNotEmpty && files.first.path != null) {
        final path = files.first.path!;
        final importResult = await DocxService.importDocx(path);

        if (importResult.unsupportedElements.isNotEmpty && mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('DOCX Import Report'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('The document was imported successfully, but some unsupported Word features were omitted:'),
                  const SizedBox(height: 8),
                  ...importResult.unsupportedElements.map((e) => Text('• $e', style: const TextStyle(fontSize: 12, color: Colors.orange))),
                ],
              ),
              actions: [
                ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Proceed to Editor')),
              ],
            ),
          );
        }

        final doc = await _docService.createNewDocument(
          title: importResult.suggestedTitle,
          initialContentJson: importResult.deltaJson,
        );

        if (mounted) {
          _openDocument(doc);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('DOCX Import error: $e')),
        );
      }
    }
  }

  Future<void> _renameDocument(DocumentModel doc) async {
    final textCtrl = TextEditingController(text: doc.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Document'),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Document Title'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, textCtrl.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle.isNotEmpty && newTitle != doc.title) {
      await _docService.renameDocument(doc, newTitle);
      _loadDocuments();
    }
  }

  Future<void> _duplicateDocument(DocumentModel doc) async {
    await _docService.duplicateDocument(doc);
    _loadDocuments();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Duplicated "${doc.title}"')),
      );
    }
  }

  Future<void> _deleteDocument(DocumentModel doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${doc.title}"?'),
        content: const Text(
          'This action will permanently remove this document and its revisions from your local device. '
          'This operation cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _docService.deleteDocument(doc);
      _loadDocuments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "${doc.title}"')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(isDark),
          if (_recoverableDrafts.isNotEmpty) _buildCrashRecoveryBanner(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              children: [
                _buildTemplatesSection(isDark),
                const SizedBox(height: 32),
                Row(
                  children: [
                    const Text(
                      'Recent Documents',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 260,
                      height: 36,
                      child: TextField(
                        controller: _searchCtrl,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Search documents...',
                          prefixIcon: const Icon(Icons.search, size: 16),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 14),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
                                    _loadDocuments();
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        onChanged: (val) {
                          setState(() => _searchQuery = val);
                          _loadDocuments();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_isLoading)
                  const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                else if (_documents.isEmpty)
                  _buildEmptyState()
                else
                  _buildDocumentsGrid(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF383838) : const Color(0xFFE2E4E8),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppConstants.wordBlue,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.description, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Text(
            AppConstants.appName,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off, size: 11, color: Colors.green),
                SizedBox(width: 4),
                Text(
                  '100% Offline Mode',
                  style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Spacer(),
          OutlinedButton.icon(
            icon: const Icon(Icons.file_open, size: 16),
            label: const Text('Open DOCX', style: TextStyle(fontSize: 12)),
            onPressed: _importDocxFile,
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.history, size: 20),
            tooltip: 'Application Activity Audit Log',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            tooltip: 'Settings & Local AI Model',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCrashRecoveryBanner() {
    return Container(
      color: Colors.amber.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Crash Recovery: Unsaved draft found for "${_recoverableDrafts.first.title}". Would you like to restore it?',
              style: TextStyle(color: Colors.amber.shade900, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final draft = _recoverableDrafts.first;
              final doc = await _docRepo.getDocumentById(draft.documentId);
              if (doc != null && mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditorScreen(
                      document: doc,
                      initialDeltaJson: draft.draftDeltaJson,
                    ),
                  ),
                );
              }
              setState(() => _recoverableDrafts = []);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade900,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(0, 30),
            ),
            child: const Text('Restore Draft', style: TextStyle(fontSize: 11)),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () async {
              for (final d in _recoverableDrafts) {
                await _recoveryService.discardDraft(d.documentId);
              }
              setState(() => _recoverableDrafts = []);
            },
            child: const Text('Dismiss', style: TextStyle(fontSize: 11, color: Colors.brown)),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplatesSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Start a new document',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildTemplateCard(
                title: 'Blank Document',
                icon: Icons.add,
                isPrimary: true,
                onTap: () => _createNewDocument(),
              ),
              const SizedBox(width: 14),
              _buildTemplateCard(
                title: 'Executive Report',
                icon: Icons.article_outlined,
                onTap: () => _createNewDocument(
                  title: 'Executive Report',
                  initialContent: jsonEncode([
                    {'insert': 'Executive Project Report\n', 'attributes': {'header': 1}},
                    {'insert': 'Prepared for Leadership Team\n', 'attributes': {'italic': true}},
                    {'insert': '\nOverview\n', 'attributes': {'header': 2}},
                    {'insert': 'This document outlines key project achievements, strategic initiatives, and roadmap milestones.\n\n'},
                    {'insert': 'Key Objectives\n', 'attributes': {'header': 2}},
                    {'insert': 'Objective 1: Accelerate offline capabilities\n', 'attributes': {'list': 'bullet'}},
                    {'insert': 'Objective 2: Enhance local AI agent responsiveness\n', 'attributes': {'list': 'bullet'}},
                    {'insert': '\n'},
                  ]),
                ),
              ),
              const SizedBox(width: 14),
              _buildTemplateCard(
                title: 'Meeting Notes',
                icon: Icons.event_note_outlined,
                onTap: () => _createNewDocument(
                  title: 'Meeting Notes',
                  initialContent: jsonEncode([
                    {'insert': 'Meeting Minutes & Action Items\n', 'attributes': {'header': 1}},
                    {'insert': 'Date: ${DateFormat('MMMM d, yyyy').format(DateTime.now())}\n'},
                    {'insert': 'Attendees: \n\n'},
                    {'insert': 'Discussion Topics\n', 'attributes': {'header': 2}},
                    {'insert': '1. Review prior sprint accomplishments\n'},
                    {'insert': '2. Identify operational blockers\n\n'},
                    {'insert': 'Action Items\n', 'attributes': {'header': 2}},
                    {'insert': 'Action Item 1: Complete offline testing verification\n', 'attributes': {'list': 'bullet'}},
                    {'insert': '\n'},
                  ]),
                ),
              ),
              const SizedBox(width: 14),
              _buildTemplateCard(
                title: 'Project Proposal',
                icon: Icons.lightbulb_outline,
                onTap: () => _createNewDocument(
                  title: 'Project Proposal',
                  initialContent: jsonEncode([
                    {'insert': 'Project Proposal: DocuCraft Architecture\n', 'attributes': {'header': 1}},
                    {'insert': '\nProblem Statement\n', 'attributes': {'header': 2}},
                    {'insert': 'Modern knowledge workers require an offline-first, private document editor capable of AI assistance.\n\n'},
                    {'insert': 'Proposed Solution\n', 'attributes': {'header': 2}},
                    {'insert': 'Provide a desktop and tablet word processor with local SQLite metadata and embedded on-device inference.\n\n'},
                  ]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 140,
        height: 120,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isPrimary ? AppConstants.wordBlue : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isPrimary ? AppConstants.wordBlue : const Color(0xFFD2D6DC),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: isPrimary ? Colors.white : AppConstants.wordBlue),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isPrimary ? Colors.white : AppConstants.textPrimaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsGrid(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.2,
          ),
          itemCount: _documents.length,
          itemBuilder: (context, index) {
            final doc = _documents[index];
            return _buildDocumentCard(doc, isDark);
          },
        );
      },
    );
  }

  Widget _buildDocumentCard(DocumentModel doc, bool isDark) {
    final modifiedDateStr = DateFormat('MMM d, h:mm a').format(doc.updatedAt);

    return Card(
      elevation: 1,
      child: InkWell(
        onTap: () => _openDocument(doc),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppConstants.wordLightBlue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.description, size: 16, color: AppConstants.wordBlue),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      doc.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (doc.isPinned)
                    const Icon(Icons.push_pin, size: 14, color: AppConstants.wordBlue),
                  _buildDocumentContextMenu(doc),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  doc.previewText.isNotEmpty ? doc.previewText : 'Blank document',
                  style: const TextStyle(fontSize: 11, color: Colors.grey, height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    modifiedDateStr,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  const Spacer(),
                  Text(
                    '${doc.wordCount} words',
                    style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentContextMenu(DocumentModel doc) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 16),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'open', child: Row(children: [Icon(Icons.open_in_new, size: 16), SizedBox(width: 8), Text('Open')])),
        const PopupMenuItem(value: 'rename', child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('Rename')])),
        const PopupMenuItem(value: 'duplicate', child: Row(children: [Icon(Icons.copy, size: 16), SizedBox(width: 8), Text('Duplicate')])),
        PopupMenuItem(
          value: 'pin',
          child: Row(
            children: [
              Icon(doc.isPinned ? Icons.push_pin_outlined : Icons.push_pin, size: 16),
              const SizedBox(width: 8),
              Text(doc.isPinned ? 'Unpin' : 'Pin to Top'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 16, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
      onSelected: (action) {
        switch (action) {
          case 'open':
            _openDocument(doc);
            break;
          case 'rename':
            _renameDocument(doc);
            break;
          case 'duplicate':
            _duplicateDocument(doc);
            break;
          case 'pin':
            _docRepo.togglePin(doc.id, !doc.isPinned).then((_) => _loadDocuments());
            break;
          case 'delete':
            _deleteDocument(doc);
            break;
        }
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(Icons.folder_open, size: 56, color: Colors.grey.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            const Text(
              'No documents found',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            const Text(
              'Click Blank Document above or Open DOCX to get started.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}
