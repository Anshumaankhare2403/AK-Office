import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'editor_controller.dart';

class FindReplaceBar extends StatefulWidget {
  final DocuCraftEditorController controller;
  final VoidCallback onClose;

  const FindReplaceBar({
    super.key,
    required this.controller,
    required this.onClose,
  });

  @override
  State<FindReplaceBar> createState() => _FindReplaceBarState();
}

class _FindReplaceBarState extends State<FindReplaceBar> {
  final TextEditingController _findCtrl = TextEditingController();
  final TextEditingController _replaceCtrl = TextEditingController();
  List<int> _matchOffsets = [];
  int _currentMatchIndex = -1;
  final bool _caseSensitive = false;

  @override
  void initState() {
    super.initState();
    _findCtrl.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _findCtrl.text;
    if (query.isEmpty) {
      setState(() {
        _matchOffsets = [];
        _currentMatchIndex = -1;
      });
      return;
    }

    final fullText = widget.controller.plainText;
    final List<int> matches = [];
    int start = 0;

    while (start < fullText.length) {
      final index = _caseSensitive
          ? fullText.indexOf(query, start)
          : fullText.toLowerCase().indexOf(query.toLowerCase(), start);

      if (index == -1) break;
      matches.add(index);
      start = index + query.length;
    }

    setState(() {
      _matchOffsets = matches;
      _currentMatchIndex = matches.isNotEmpty ? 0 : -1;
    });

    if (matches.isNotEmpty) {
      _highlightCurrentMatch();
    }
  }

  void _highlightCurrentMatch() {
    if (_currentMatchIndex >= 0 && _currentMatchIndex < _matchOffsets.length) {
      final offset = _matchOffsets[_currentMatchIndex];
      final len = _findCtrl.text.length;
      widget.controller.quillController.updateSelection(
        TextSelection(baseOffset: offset, extentOffset: offset + len),
        ChangeSource.local,
      );
    }
  }

  void _nextMatch() {
    if (_matchOffsets.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _matchOffsets.length;
    });
    _highlightCurrentMatch();
  }

  void _prevMatch() {
    if (_matchOffsets.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex - 1 + _matchOffsets.length) % _matchOffsets.length;
    });
    _highlightCurrentMatch();
  }

  void _replaceCurrent() {
    if (_currentMatchIndex >= 0 && _currentMatchIndex < _matchOffsets.length) {
      final offset = _matchOffsets[_currentMatchIndex];
      final len = _findCtrl.text.length;
      final replacement = _replaceCtrl.text;

      widget.controller.quillController.document.replace(offset, len, replacement);
      widget.controller.quillController.updateSelection(
        TextSelection.collapsed(offset: offset + replacement.length),
        ChangeSource.local,
      );
      _onSearchChanged();
    }
  }

  void _replaceAll() {
    final query = _findCtrl.text;
    final replacement = _replaceCtrl.text;
    if (query.isEmpty) return;

    var fullText = widget.controller.plainText;
    int count = 0;
    while (true) {
      final index = _caseSensitive
          ? fullText.indexOf(query)
          : fullText.toLowerCase().indexOf(query.toLowerCase());
      if (index == -1) break;

      widget.controller.quillController.document.replace(index, query.length, replacement);
      count++;
      fullText = widget.controller.plainText;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Replaced $count occurrences of "$query"')),
    );
    _onSearchChanged();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF282828) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF404040) : const Color(0xFFD2D6DC),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 200,
            height: 32,
            child: TextField(
              controller: _findCtrl,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Find...',
                prefixIcon: const Icon(Icons.search, size: 16),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                suffixText: _matchOffsets.isNotEmpty
                    ? '${_currentMatchIndex + 1}/${_matchOffsets.length}'
                    : (_findCtrl.text.isNotEmpty ? '0/0' : null),
                suffixStyle: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.arrow_upward, size: 16),
            tooltip: 'Previous match',
            onPressed: _prevMatch,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_downward, size: 16),
            tooltip: 'Next match',
            onPressed: _nextMatch,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 200,
            height: 32,
            child: TextField(
              controller: _replaceCtrl,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'Replace with...',
                prefixIcon: Icon(Icons.find_replace, size: 16),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
            ),
          ),
          const SizedBox(width: 6),
          OutlinedButton(
            onPressed: _matchOffsets.isNotEmpty ? _replaceCurrent : null,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(60, 30),
            ),
            child: const Text('Replace', style: TextStyle(fontSize: 11)),
          ),
          const SizedBox(width: 4),
          OutlinedButton(
            onPressed: _matchOffsets.isNotEmpty ? _replaceAll : null,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(76, 30),
            ),
            child: const Text('Replace All', style: TextStyle(fontSize: 11)),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            tooltip: 'Close Find & Replace',
            onPressed: widget.onClose,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _findCtrl.dispose();
    _replaceCtrl.dispose();
    super.dispose();
  }
}
