import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../core/constants/app_constants.dart';
import '../models/document_model.dart';
import '../models/page_settings_model.dart';
import '../services/document_service.dart';

class EditorState {
  final DocumentModel document;
  final bool isDirty;
  final bool isSaving;
  final int wordCount;
  final int characterCount;
  final String statusMessage;

  EditorState({
    required this.document,
    this.isDirty = false,
    this.isSaving = false,
    this.wordCount = 0,
    this.characterCount = 0,
    this.statusMessage = 'Saved',
  });

  EditorState copyWith({
    DocumentModel? document,
    bool? isDirty,
    bool? isSaving,
    int? wordCount,
    int? characterCount,
    String? statusMessage,
  }) {
    return EditorState(
      document: document ?? this.document,
      isDirty: isDirty ?? this.isDirty,
      isSaving: isSaving ?? this.isSaving,
      wordCount: wordCount ?? this.wordCount,
      characterCount: characterCount ?? this.characterCount,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

class DocuCraftEditorController extends ChangeNotifier {
  final DocumentService _docService;
  DocumentModel _document;
  late final QuillController _quillController;

  bool _isDirty = false;
  bool _isSaving = false;
  int _wordCount = 0;
  int _characterCount = 0;
  String _statusMessage = 'Saved';
  Timer? _autosaveTimer;

  DocuCraftEditorController({
    required DocumentModel document,
    required String initialDeltaJson,
    DocumentService? docService,
  })  : // ignore: prefer_initializing_formals
        _document = document,
        _docService = docService ?? DocumentService() {
    Document doc;
    try {
      final List<dynamic> ops = jsonDecode(initialDeltaJson) as List<dynamic>;
      doc = Document.fromJson(ops);
    } catch (_) {
      doc = Document()..insert(0, '\n');
    }

    _quillController = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );

    _updateCounts();
    _quillController.addListener(_onDocChanged);
  }

  DocumentModel get document => _document;
  QuillController get quillController => _quillController;
  bool get isDirty => _isDirty;
  bool get isSaving => _isSaving;
  int get wordCount => _wordCount;
  int get characterCount => _characterCount;
  String get statusMessage => _statusMessage;

  String get deltaJson => jsonEncode(_quillController.document.toDelta().toJson());
  String get plainText => _quillController.document.toPlainText();

  String? get selectedText {
    final selection = _quillController.selection;
    if (selection.isCollapsed) return null;
    final text = plainText;
    final start = selection.start.clamp(0, text.length);
    final end = selection.end.clamp(0, text.length);
    if (start >= end) return null;
    return text.substring(start, end);
  }

  int get cursorOffset => _quillController.selection.baseOffset;

  void _onDocChanged() {
    _updateCounts();
    if (!_isDirty) {
      _isDirty = true;
      _statusMessage = 'Unsaved changes';
      notifyListeners();
    }

    // Debounced draft autosave
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: AppConstants.autosaveDebounceMs), () {
      _saveDraft();
    });
  }

  void _updateCounts() {
    final text = plainText.trim();
    _characterCount = text.replaceAll(RegExp(r'\s'), '').length;
    _wordCount = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
  }

  Future<void> _saveDraft() async {
    if (!_isDirty) return;
    try {
      await _docService.saveDraft(_document.id, _document.title, deltaJson);
    } catch (_) {}
  }

  /// Explicit user save
  Future<void> save({bool createRevision = false, String? revisionSummary}) async {
    if (_isSaving) return;
    _isSaving = true;
    _statusMessage = 'Saving...';
    notifyListeners();

    try {
      final updatedDoc = await _docService.saveDocument(
        doc: _document,
        deltaJson: deltaJson,
        plainText: plainText,
        createRevision: createRevision,
        revisionSummary: revisionSummary,
      );
      _document = updatedDoc;
      _isDirty = false;
      _statusMessage = 'Saved';
    } catch (e) {
      _statusMessage = 'Save failed: $e';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Update page settings (A4/Letter, Margins, Orientation)
  Future<void> updatePageSettings(PageSettingsModel newSettings) async {
    _document = _document.copyWith(pageSettings: newSettings);
    _isDirty = true;
    _statusMessage = 'Unsaved changes';
    notifyListeners();
    await save();
  }

  /// Insert text at current cursor
  void insertTextAtCursor(String text) {
    final offset = _quillController.selection.baseOffset;
    final safeOffset = offset.clamp(0, _quillController.document.length - 1);
    _quillController.document.insert(safeOffset, text);
    _quillController.updateSelection(
      TextSelection.collapsed(offset: safeOffset + text.length),
      ChangeSource.local,
    );
  }

  /// Replace target text in document
  bool replaceTargetText(String targetText, String replacement) {
    final fullText = plainText;
    final index = fullText.indexOf(targetText);
    if (index != -1) {
      _quillController.document.replace(index, targetText.length, replacement);
      _quillController.updateSelection(
        TextSelection.collapsed(offset: index + replacement.length),
        ChangeSource.local,
      );
      return true;
    }
    return false;
  }

  /// Replace selected text
  void replaceSelection(String replacement) {
    final selection = _quillController.selection;
    if (selection.isCollapsed) {
      insertTextAtCursor(replacement);
    } else {
      _quillController.document.replace(
        selection.start,
        selection.end - selection.start,
        replacement,
      );
      _quillController.updateSelection(
        TextSelection.collapsed(offset: selection.start + replacement.length),
        ChangeSource.local,
      );
    }
  }

  /// Formatting helpers
  void toggleBold() {
    final isBold = _quillController.getSelectionStyle().attributes.containsKey(Attribute.bold.key);
    _quillController.formatSelection(isBold ? Attribute.clone(Attribute.bold, null) : Attribute.bold);
  }

  void toggleItalic() {
    final isItalic = _quillController.getSelectionStyle().attributes.containsKey(Attribute.italic.key);
    _quillController.formatSelection(isItalic ? Attribute.clone(Attribute.italic, null) : Attribute.italic);
  }

  void toggleUnderline() {
    final isUnderline = _quillController.getSelectionStyle().attributes.containsKey(Attribute.underline.key);
    _quillController.formatSelection(isUnderline ? Attribute.clone(Attribute.underline, null) : Attribute.underline);
  }

  void toggleStrike() {
    final isStrike = _quillController.getSelectionStyle().attributes.containsKey(Attribute.strikeThrough.key);
    _quillController.formatSelection(isStrike ? Attribute.clone(Attribute.strikeThrough, null) : Attribute.strikeThrough);
  }

  void setHeading(int? level) {
    if (level == 1) {
      _quillController.formatSelection(Attribute.h1);
    } else if (level == 2) {
      _quillController.formatSelection(Attribute.h2);
    } else if (level == 3) {
      _quillController.formatSelection(Attribute.h3);
    } else {
      _quillController.formatSelection(Attribute.header);
    }
  }

  void setAlignment(String? align) {
    if (align == 'center') {
      _quillController.formatSelection(Attribute.centerAlignment);
    } else if (align == 'right') {
      _quillController.formatSelection(Attribute.rightAlignment);
    } else if (align == 'justify') {
      _quillController.formatSelection(Attribute.justifyAlignment);
    } else {
      _quillController.formatSelection(Attribute.leftAlignment);
    }
  }

  void toggleBulletList() {
    final isBullet = _quillController.getSelectionStyle().attributes.containsKey(Attribute.ul.key);
    _quillController.formatSelection(isBullet ? Attribute.clone(Attribute.ul, null) : Attribute.ul);
  }

  void toggleNumberedList() {
    final isNumber = _quillController.getSelectionStyle().attributes.containsKey(Attribute.ol.key);
    _quillController.formatSelection(isNumber ? Attribute.clone(Attribute.ol, null) : Attribute.ol);
  }

  void insertTable(int rows, int cols) {
    final buf = StringBuffer('\n');
    for (int r = 0; r < rows; r++) {
      buf.write('|');
      for (int c = 0; c < cols; c++) {
        buf.write(' Cell ${r + 1},${c + 1} |');
      }
      buf.writeln();
      if (r == 0) {
        buf.write('|');
        for (int c = 0; c < cols; c++) {
          buf.write(' :--- |');
        }
        buf.writeln();
      }
    }
    buf.writeln();
    insertTextAtCursor(buf.toString());
  }

  void insertPageBreak() {
    insertTextAtCursor('\n--- [Page Break] ---\n');
  }

  void undo() {
    if (_quillController.hasUndo) {
      _quillController.undo();
    }
  }

  void redo() {
    if (_quillController.hasRedo) {
      _quillController.redo();
    }
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _quillController.removeListener(_onDocChanged);
    _quillController.dispose();
    super.dispose();
  }
}
