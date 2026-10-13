import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../ai/document_context_service.dart';
import '../core/constants/app_constants.dart';
import 'editor_controller.dart';

class DocuCraftOutlinePanel extends StatelessWidget {
  final DocuCraftEditorController controller;
  final VoidCallback onClose;

  const DocuCraftOutlinePanel({
    super.key,
    required this.controller,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final outline = DocumentContextService.extractOutline(controller.deltaJson);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF222222) : const Color(0xFFF9FAFB),
        border: Border(
          right: BorderSide(
            color: isDark ? const Color(0xFF383838) : const Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF383838) : const Color(0xFFE5E7EB),
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.list_alt, size: 18, color: AppConstants.wordBlue),
                const SizedBox(width: 8),
                const Text(
                  'Navigation',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: onClose,
                  tooltip: 'Close Navigation Panel',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Expanded(
            child: outline.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.format_list_bulleted, size: 32, color: Colors.grey.withValues(alpha: 0.5)),
                          const SizedBox(height: 8),
                          const Text(
                            'No headings in document.',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Add Headings from the Home tab to build an outline.',
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: outline.length,
                    itemBuilder: (context, index) {
                      final item = outline[index];
                      final double indent = (item.level - 1) * 12.0;

                      return InkWell(
                        onTap: () {
                          final docLen = controller.quillController.document.length;
                          final safeOffset = item.offset.clamp(0, docLen - 1);
                          controller.quillController.updateSelection(
                            TextSelection.collapsed(offset: safeOffset),
                            ChangeSource.local,
                          );
                        },
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(12 + indent, 6, 12, 6),
                          child: Row(
                            children: [
                              Icon(
                                item.level == 1 ? Icons.circle : Icons.arrow_right,
                                size: item.level == 1 ? 6 : 14,
                                color: AppConstants.wordBlue,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: TextStyle(
                                    fontSize: item.level == 1 ? 13 : 12,
                                    fontWeight: item.level == 1 ? FontWeight.w600 : FontWeight.normal,
                                    color: isDark ? Colors.white : AppConstants.textPrimaryLight,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
