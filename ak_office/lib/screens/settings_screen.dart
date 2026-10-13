import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../ai/ai_service.dart';
import '../core/constants/app_constants.dart';
import '../core/utilities/file_utils.dart';
import '../repositories/recovery_repository.dart';

class SettingsScreen extends StatefulWidget {
  final AiService? aiService;
  final VoidCallback? onThemeChanged;

  const SettingsScreen({
    super.key,
    this.aiService,
    this.onThemeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final AiService _aiService;
  final RecoveryRepository _recoveryRepo = RecoveryRepository();

  String _modelStatus = 'Loading status...';
  String _appDirPath = '';

  @override
  void initState() {
    super.initState();
    _aiService = widget.aiService ?? AiService();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final status = await _aiService.getEngineStatus();
    final dir = await FileUtils.getAppBaseDirectory();
    if (mounted) {
      setState(() {
        _modelStatus = status;
        _appDirPath = dir.path;
      });
    }
  }

  Future<void> _pickModelFile() async {
    try {
      final files = await FilePicker.pickFiles(
        dialogTitle: 'Select Local GGUF Model',
        type: FileType.custom,
        allowedExtensions: ['gguf', 'bin'],
      );

      if (files.isNotEmpty && files.first.path != null) {
        final path = files.first.path!;
        final name = files.first.name;
        _aiService.localModel.setModelPath(path);
        await _loadSettings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Configured local model: $name')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick model: $e')),
        );
      }
    }
  }

  void _resetModel() async {
    _aiService.localModel.setModelPath(null);
    await _loadSettings();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reset to default offline semantic engine.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DocuCraft Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionHeader('Offline AI Model Engine', Icons.auto_awesome),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield_outlined, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '100% Offline & Private',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'DocuCraft runs completely on your device without transmitting documents to the cloud. '
                    'You can use the built-in intelligent semantic engine or import your own local GGUF model.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const Divider(height: 24),
                  Text('Current Engine: $_modelStatus', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.file_open, size: 16),
                        label: const Text('Import GGUF Model', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.wordBlue,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _pickModelFile,
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: _resetModel,
                        child: const Text('Reset to Built-in Engine', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          _buildSectionHeader('Storage & Maintenance', Icons.folder),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Local Application Path: $_appDirPath', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.cleaning_services, size: 16),
                        label: const Text('Clear Crash Drafts', style: TextStyle(fontSize: 12)),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final drafts = await _recoveryRepo.getAllDrafts();
                          for (final d in drafts) {
                            await _recoveryRepo.deleteDraft(d.documentId);
                          }
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Cleared temporary crash recovery drafts.')),
                          );
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.delete_sweep, size: 16),
                        label: const Text('Clear AI Chat Cache', style: TextStyle(fontSize: 12)),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await _aiService.clearChatHistory(null);
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Cleared AI conversation history.')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          _buildSectionHeader('About DocuCraft', Icons.info_outline),
          Card(
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DocuCraft — Offline Document Processor',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text('Version: 1.0.0 (Release Candidate)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text(
                    'Engineered with Flutter, Dart, SQLite, and custom Open Packaging Conventions (OPC) '
                    'WordprocessingML DOCX architecture. Integrated with an offline agentic copilot.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppConstants.wordBlue),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
