import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../core/constants/app_constants.dart';
import 'editor_controller.dart';

class DocuCraftCanvas extends StatefulWidget {
  final DocuCraftEditorController controller;
  final VoidCallback onToggleAi;
  final bool isAiOpen;

  const DocuCraftCanvas({
    super.key,
    required this.controller,
    required this.onToggleAi,
    this.isAiOpen = false,
  });

  @override
  State<DocuCraftCanvas> createState() => _DocuCraftCanvasState();
}

class _DocuCraftCanvasState extends State<DocuCraftCanvas> {
  double _zoomScale = 1.0;
  final FocusNode _editorFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _editorFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageSettings = widget.controller.document.pageSettings;

    return Column(
      children: [
        // Main Scrollable Canvas Area
        Expanded(
          child: Container(
            color: isDark ? AppConstants.canvasBackgroundDark : AppConstants.canvasBackgroundLight,
            child: InteractiveViewer(
              transformationController: null,
              scaleEnabled: false, // We control zoom explicitly via status bar
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                child: Center(
                  child: Transform.scale(
                    scale: _zoomScale,
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: pageSettings.width,
                      constraints: BoxConstraints(minHeight: pageSettings.height),
                      decoration: BoxDecoration(
                        color: Colors.white, // True paper feel
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 12,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header area
                          if (pageSettings.headerText != null && pageSettings.headerText!.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                pageSettings.marginLeft,
                                20,
                                pageSettings.marginRight,
                                0,
                              ),
                              child: Text(
                                pageSettings.headerText!,
                                textAlign: TextAlign.right,
                                style: const TextStyle(color: Color(0xFF888888), fontSize: 10),
                              ),
                            ),

                          // Document Editing Body
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              pageSettings.marginLeft,
                              pageSettings.marginTop,
                              pageSettings.marginRight,
                              pageSettings.marginBottom,
                            ),
                            child: Theme(
                              // Force dark text inside white paper
                              data: ThemeData.light().copyWith(
                                textSelectionTheme: const TextSelectionThemeData(
                                  selectionColor: Color(0xFFCCE8FF),
                                  cursorColor: AppConstants.wordBlue,
                                ),
                              ),
                              child: QuillEditor.basic(
                                controller: widget.controller.quillController,
                                focusNode: _editorFocusNode,
                              ),
                            ),
                          ),

                          // Footer area
                          if (pageSettings.showPageNumbers || (pageSettings.footerText != null && pageSettings.footerText!.isNotEmpty))
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                pageSettings.marginLeft,
                                0,
                                pageSettings.marginRight,
                                24,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    pageSettings.footerText ?? '',
                                    style: const TextStyle(color: Color(0xFF888888), fontSize: 10),
                                  ),
                                  if (pageSettings.showPageNumbers)
                                    const Text(
                                      'Page 1',
                                      style: TextStyle(color: Color(0xFF888888), fontSize: 10),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Bottom Word-style Status Bar
        _buildStatusBar(isDark),
      ],
    );
  }

  Widget _buildStatusBar(bool isDark) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF3F5F8),
            border: Border(
              top: BorderSide(
                color: isDark ? const Color(0xFF383838) : const Color(0xFFD2D6DC),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // Page indicator
              const Text('Page 1 of 1', style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(width: 16),

              // Word count
              Text(
                '${widget.controller.wordCount} words',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(width: 16),

              // Character count
              Text(
                '${widget.controller.characterCount} characters',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(width: 16),

              // Save Status badge
              _buildSaveBadge(),

              const Spacer(),

              // Quick AI Assistant toggle
              InkWell(
                onTap: widget.onToggleAi,
                borderRadius: BorderRadius.circular(3),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 13,
                        color: widget.isAiOpen ? AppConstants.wordBlue : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'AI Agent',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: widget.isAiOpen ? FontWeight.bold : FontWeight.normal,
                          color: widget.isAiOpen ? AppConstants.wordBlue : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Zoom controls
              IconButton(
                icon: const Icon(Icons.remove, size: 12),
                tooltip: 'Zoom Out',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  if (_zoomScale > 0.6) {
                    setState(() => _zoomScale = (_zoomScale - 0.1).clamp(0.5, 2.0));
                  }
                },
              ),
              const SizedBox(width: 4),
              Text(
                '${(_zoomScale * 100).round()}%',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.add, size: 12),
                tooltip: 'Zoom In',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  if (_zoomScale < 1.8) {
                    setState(() => _zoomScale = (_zoomScale + 0.1).clamp(0.5, 2.0));
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSaveBadge() {
    if (widget.controller.isSaving) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: AppConstants.wordBlue),
          ),
          SizedBox(width: 6),
          Text('Saving...', style: TextStyle(fontSize: 11, color: AppConstants.wordBlue)),
        ],
      );
    }

    if (widget.controller.isDirty) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 7, color: Colors.orange),
          SizedBox(width: 5),
          Text('Unsaved changes', style: TextStyle(fontSize: 11, color: Colors.orange)),
        ],
      );
    }

    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle_outline, size: 12, color: Colors.green),
        SizedBox(width: 4),
        Text('Saved', style: TextStyle(fontSize: 11, color: Colors.green)),
      ],
    );
  }
}
