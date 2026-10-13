import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../models/page_settings_model.dart';
import 'editor_controller.dart';

enum RibbonTab { home, insert, layout, view, file }

class DocuCraftRibbonToolbar extends StatefulWidget {
  final DocuCraftEditorController controller;
  final VoidCallback onSave;
  final VoidCallback onExportDocx;
  final VoidCallback onExportPdf;
  final VoidCallback onPrint;
  final VoidCallback onOpenHistory;
  final VoidCallback onToggleOutline;
  final VoidCallback onToggleAi;
  final bool isOutlineOpen;
  final bool isAiOpen;

  const DocuCraftRibbonToolbar({
    super.key,
    required this.controller,
    required this.onSave,
    required this.onExportDocx,
    required this.onExportPdf,
    required this.onPrint,
    required this.onOpenHistory,
    required this.onToggleOutline,
    required this.onToggleAi,
    this.isOutlineOpen = false,
    this.isAiOpen = false,
  });

  @override
  State<DocuCraftRibbonToolbar> createState() => _DocuCraftRibbonToolbarState();
}

class _DocuCraftRibbonToolbarState extends State<DocuCraftRibbonToolbar> {
  RibbonTab _activeTab = RibbonTab.home;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ribbonBg = isDark ? AppConstants.ribbonBackgroundDark : AppConstants.ribbonBackgroundLight;

    return Container(
      decoration: BoxDecoration(
        color: ribbonBg,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF383838) : const Color(0xFFD2D6DC),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTabBar(isDark),
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildTabCommands(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1B1B) : const Color(0xFFE9ECF0),
      ),
      child: Row(
        children: [
          _buildFileTabButton(),
          const SizedBox(width: 4),
          _buildTabItem('Home', RibbonTab.home, isDark),
          _buildTabItem('Insert', RibbonTab.insert, isDark),
          _buildTabItem('Layout', RibbonTab.layout, isDark),
          _buildTabItem('View', RibbonTab.view, isDark),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.save_outlined, size: 16),
            tooltip: 'Save Document (Ctrl+S)',
            onPressed: widget.onSave,
          ),
          IconButton(
            icon: const Icon(Icons.undo, size: 16),
            tooltip: 'Undo (Ctrl+Z)',
            onPressed: widget.controller.undo,
          ),
          IconButton(
            icon: const Icon(Icons.redo, size: 16),
            tooltip: 'Redo (Ctrl+Y)',
            onPressed: widget.controller.redo,
          ),
        ],
      ),
    );
  }

  Widget _buildFileTabButton() {
    return InkWell(
      onTap: () {
        setState(() => _activeTab = RibbonTab.file);
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: AppConstants.wordBlue,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'File',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(String label, RibbonTab tab, bool isDark) {
    final isSelected = _activeTab == tab;
    return InkWell(
      onTap: () => setState(() => _activeTab = tab),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppConstants.wordBlue : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? AppConstants.wordBlue
                : (isDark ? Colors.white70 : AppConstants.textPrimaryLight),
          ),
        ),
      ),
    );
  }

  Widget _buildTabCommands(bool isDark) {
    switch (_activeTab) {
      case RibbonTab.home:
        return _buildHomeTab(isDark);
      case RibbonTab.insert:
        return _buildInsertTab(isDark);
      case RibbonTab.layout:
        return _buildLayoutTab(isDark);
      case RibbonTab.view:
        return _buildViewTab(isDark);
      case RibbonTab.file:
        return _buildFileTab(isDark);
    }
  }

  Widget _buildHomeTab(bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildToolButton(icon: Icons.undo, tooltip: 'Undo', onTap: widget.controller.undo),
        _buildToolButton(icon: Icons.redo, tooltip: 'Redo', onTap: widget.controller.redo),
        _buildDivider(isDark),
        _buildHeadingSelector(),
        _buildDivider(isDark),
        _buildToolButton(icon: Icons.format_bold, tooltip: 'Bold (Ctrl+B)', onTap: widget.controller.toggleBold),
        _buildToolButton(icon: Icons.format_italic, tooltip: 'Italic (Ctrl+I)', onTap: widget.controller.toggleItalic),
        _buildToolButton(icon: Icons.format_underlined, tooltip: 'Underline (Ctrl+U)', onTap: widget.controller.toggleUnderline),
        _buildToolButton(icon: Icons.format_strikethrough, tooltip: 'Strikethrough', onTap: widget.controller.toggleStrike),
        _buildDivider(isDark),
        _buildToolButton(icon: Icons.format_align_left, tooltip: 'Align Left', onTap: () => widget.controller.setAlignment('left')),
        _buildToolButton(icon: Icons.format_align_center, tooltip: 'Align Center', onTap: () => widget.controller.setAlignment('center')),
        _buildToolButton(icon: Icons.format_align_right, tooltip: 'Align Right', onTap: () => widget.controller.setAlignment('right')),
        _buildToolButton(icon: Icons.format_align_justify, tooltip: 'Justify', onTap: () => widget.controller.setAlignment('justify')),
        _buildDivider(isDark),
        _buildToolButton(icon: Icons.format_list_bulleted, tooltip: 'Bulleted List', onTap: widget.controller.toggleBulletList),
        _buildToolButton(icon: Icons.format_list_numbered, tooltip: 'Numbered List', onTap: widget.controller.toggleNumberedList),
      ],
    );
  }

  Widget _buildInsertTab(bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLabelButton(
          icon: Icons.table_chart_outlined,
          label: 'Table',
          tooltip: 'Insert Table',
          onTap: () => _showInsertTableDialog(context),
        ),
        _buildLabelButton(
          icon: Icons.image_outlined,
          label: 'Image',
          tooltip: 'Insert Image',
          onTap: () => _showInsertImageDialog(context),
        ),
        _buildDivider(isDark),
        _buildLabelButton(
          icon: Icons.insert_page_break_outlined,
          label: 'Page Break',
          tooltip: 'Insert Page Break',
          onTap: widget.controller.insertPageBreak,
        ),
        _buildLabelButton(
          icon: Icons.link_outlined,
          label: 'Link',
          tooltip: 'Insert Link',
          onTap: () => _showInsertLinkDialog(context),
        ),
      ],
    );
  }

  Widget _buildLayoutTab(bool isDark) {
    final settings = widget.controller.document.pageSettings;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButton<PageFormatType>(
          value: settings.format,
          underline: const SizedBox(),
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white : AppConstants.textPrimaryLight,
          ),
          items: const [
            DropdownMenuItem(value: PageFormatType.a4, child: Text('A4 (210 x 297 mm)')),
            DropdownMenuItem(value: PageFormatType.letter, child: Text('Letter (8.5" x 11")')),
            DropdownMenuItem(value: PageFormatType.legal, child: Text('Legal (8.5" x 14")')),
          ],
          onChanged: (fmt) {
            if (fmt != null) {
              widget.controller.updatePageSettings(settings.copyWith(format: fmt));
            }
          },
        ),
        _buildDivider(isDark),
        _buildLabelButton(
          icon: Icons.portrait,
          label: 'Portrait',
          isActive: settings.orientation == PageOrientationType.portrait,
          onTap: () {
            widget.controller.updatePageSettings(settings.copyWith(orientation: PageOrientationType.portrait));
          },
        ),
        _buildLabelButton(
          icon: Icons.landscape,
          label: 'Landscape',
          isActive: settings.orientation == PageOrientationType.landscape,
          onTap: () {
            widget.controller.updatePageSettings(settings.copyWith(orientation: PageOrientationType.landscape));
          },
        ),
        _buildDivider(isDark),
        PopupMenuButton<double>(
          tooltip: 'Margins',
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.border_outer, size: 18),
              SizedBox(width: 4),
              Text('Margins', style: TextStyle(fontSize: 12)),
              Icon(Icons.arrow_drop_down, size: 16),
            ],
          ),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 72.0, child: Text('Normal (1.0 inch / 72 pt)')),
            const PopupMenuItem(value: 36.0, child: Text('Narrow (0.5 inch / 36 pt)')),
            const PopupMenuItem(value: 108.0, child: Text('Wide (1.5 inch / 108 pt)')),
          ],
          onSelected: (margin) {
            widget.controller.updatePageSettings(settings.copyWith(
              marginTop: margin,
              marginBottom: margin,
              marginLeft: margin,
              marginRight: margin,
            ));
          },
        ),
      ],
    );
  }

  Widget _buildViewTab(bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLabelButton(
          icon: Icons.list_alt,
          label: 'Outline',
          isActive: widget.isOutlineOpen,
          tooltip: 'Toggle Document Headings Outline',
          onTap: widget.onToggleOutline,
        ),
        _buildLabelButton(
          icon: Icons.auto_awesome,
          label: 'AI Assistant',
          isActive: widget.isAiOpen,
          tooltip: 'Toggle Offline AI Assistant Panel',
          onTap: widget.onToggleAi,
        ),
        _buildDivider(isDark),
        _buildLabelButton(
          icon: Icons.history,
          label: 'Version History',
          tooltip: 'View Document Revisions & Activity Log',
          onTap: widget.onOpenHistory,
        ),
      ],
    );
  }

  Widget _buildFileTab(bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLabelButton(
          icon: Icons.save,
          label: 'Save',
          tooltip: 'Save document (Ctrl+S)',
          onTap: widget.onSave,
        ),
        _buildLabelButton(
          icon: Icons.description_outlined,
          label: 'Export DOCX',
          tooltip: 'Export as Microsoft Word (.docx)',
          onTap: widget.onExportDocx,
        ),
        _buildLabelButton(
          icon: Icons.picture_as_pdf_outlined,
          label: 'Export PDF',
          tooltip: 'Export as Adobe PDF (.pdf)',
          onTap: widget.onExportPdf,
        ),
        _buildLabelButton(
          icon: Icons.print_outlined,
          label: 'Print',
          tooltip: 'Print document or preview (Ctrl+P)',
          onTap: widget.onPrint,
        ),
        _buildDivider(isDark),
        _buildLabelButton(
          icon: Icons.history_outlined,
          label: 'History & Revisions',
          tooltip: 'Inspect revision timeline',
          onTap: widget.onOpenHistory,
        ),
      ],
    );
  }

  Widget _buildHeadingSelector() {
    return PopupMenuButton<int?>(
      tooltip: 'Heading Styles',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Styles', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(value: null, child: Text('Normal Text')),
        const PopupMenuItem(
          value: 1,
          child: Text('Heading 1', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.wordBlue)),
        ),
        const PopupMenuItem(
          value: 2,
          child: Text('Heading 2', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppConstants.wordDarkBlue)),
        ),
        const PopupMenuItem(
          value: 3,
          child: Text('Heading 3', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ),
      ],
      onSelected: (level) => widget.controller.setHeading(level),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(6),
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: isActive ? AppConstants.wordLightBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isActive ? AppConstants.wordBlue : null,
          ),
        ),
      ),
    );
  }

  Widget _buildLabelButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? tooltip,
    bool isActive = false,
  }) {
    final button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isActive ? AppConstants.wordLightBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: isActive ? Border.all(color: AppConstants.wordBlue.withValues(alpha: 0.4)) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isActive ? AppConstants.wordBlue : null),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? AppConstants.wordBlue : null,
              ),
            ),
          ],
        ),
      ),
    );

    return tooltip != null ? Tooltip(message: tooltip, child: button) : button;
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      height: 24,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: isDark ? const Color(0xFF444444) : const Color(0xFFD4D8DD),
    );
  }

  void _showInsertTableDialog(BuildContext context) {
    int rows = 3;
    int cols = 3;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Insert Table'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('Rows: '),
                const Spacer(),
                DropdownButton<int>(
                  value: rows,
                  items: [2, 3, 4, 5, 6, 8]
                      .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => rows = v);
                  },
                ),
              ],
            ),
            Row(
              children: [
                const Text('Columns: '),
                const Spacer(),
                DropdownButton<int>(
                  value: cols,
                  items: [2, 3, 4, 5, 6]
                      .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => cols = v);
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.controller.insertTable(rows, cols);
            },
            child: const Text('Insert'),
          ),
        ],
      ),
    );
  }

  void _showInsertImageDialog(BuildContext context) {
    final textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Insert Image'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter local image path or description:', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: textCtrl,
              decoration: const InputDecoration(
                hintText: 'C:\\path\\to\\image.png or [Figure 1: Diagram]',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (textCtrl.text.isNotEmpty) {
                widget.controller.insertTextAtCursor('\n![Image: ${textCtrl.text}](${textCtrl.text})\n');
              }
            },
            child: const Text('Insert'),
          ),
        ],
      ),
    );
  }

  void _showInsertLinkDialog(BuildContext context) {
    final textCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Insert Hyperlink'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: textCtrl, decoration: const InputDecoration(labelText: 'Display Text')),
            const SizedBox(height: 8),
            TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'Target URL')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (textCtrl.text.isNotEmpty && urlCtrl.text.isNotEmpty) {
                widget.controller.insertTextAtCursor('[${textCtrl.text}](${urlCtrl.text})');
              }
            },
            child: const Text('Insert'),
          ),
        ],
      ),
    );
  }
}
