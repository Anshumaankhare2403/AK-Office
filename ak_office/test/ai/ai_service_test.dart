import 'package:flutter_test/flutter_test.dart';
import 'package:ak_office/ai/ai_context_models.dart';
import 'package:ak_office/ai/local_model_service.dart';
import 'package:ak_office/models/activity_model.dart';
import 'package:ak_office/models/ai_message_model.dart';
import 'package:ak_office/models/ai_tool_model.dart';
import 'package:ak_office/models/document_model.dart';

void main() {
  group('Local AI Service & Safety Permission Gate Tests', () {
    late LocalModelService localModel;

    setUp(() {
      localModel = LocalModelService();
    });

    test('Offline Model status declares 100% on-device operation', () async {
      final status = await localModel.getModelStatus();
      expect(status.contains('on-device'), true);
      expect(status.contains('0 network'), true);
    });

    test('Summarization extracts salient content from document', () async {
      final doc = DocumentModel(
        id: 'doc-ai-1',
        title: 'Project Antigravity',
        filePath: 'test.docucraft',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        lastOpenedAt: DateTime.now(),
      );

      const text = 'Project Antigravity is an advanced software engineering system. '
          'It facilitates high velocity pair programming and deep code reasoning. '
          'The offline document processor guarantees full data privacy and zero cloud dependencies. '
          'Teams can iterate rapidly without experiencing latency.';

      final context = AiPromptContext(
        userPrompt: 'Summarize this document',
        currentDocument: doc,
        currentDocumentPlainText: text,
      );

      final response = await localModel.processPrompt(context);
      expect(response.role, AiMessageRole.assistant);
      expect(response.content.contains('Executive Summary'), true);
    });

    test('Grammar check identifies typos and produces permission-gated proposals', () async {
      final doc = DocumentModel(
        id: 'doc-ai-2',
        title: 'Draft',
        filePath: 'test.docucraft',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        lastOpenedAt: DateTime.now(),
      );

      const text = 'We will recieve teh final report tomorrow.';

      final context = AiPromptContext(
        userPrompt: 'Find grammar and spelling mistakes',
        currentDocument: doc,
        currentDocumentPlainText: text,
      );

      final response = await localModel.processPrompt(context);
      expect(response.proposals.isNotEmpty, true);

      // Verify permission gate requirement
      for (final p in response.proposals) {
        expect(p.requiresConfirmation, true, reason: 'AI must require user confirmation before applying changes');
        expect(p.status, ToolProposalStatus.pending, reason: 'Proposals must start in pending state');
      }
    });

    test('Activity query retrieves document save and event history', () async {
      final now = DateTime.now();
      final doc = DocumentModel(
        id: 'doc-ai-3',
        title: 'Financial Model',
        filePath: 'test.docucraft',
        createdAt: now.subtract(const Duration(hours: 3)),
        updatedAt: now.subtract(const Duration(minutes: 15)),
        lastOpenedAt: now,
      );

      final activities = [
        ActivityModel(
          id: 'act-1',
          documentId: doc.id,
          documentTitle: doc.title,
          eventType: ActivityEventType.documentSaved,
          timestamp: now.subtract(const Duration(minutes: 15)),
          description: 'Saved document "${doc.title}" (450 words)',
        ),
      ];

      final context = AiPromptContext(
        userPrompt: 'When was this document last saved?',
        currentDocument: doc,
        recentActivities: activities,
      );

      final response = await localModel.processPrompt(context);
      expect(response.content.contains('last saved'), true);
      expect(response.content.contains('Financial Model'), true);
    });
  });
}
