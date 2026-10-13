import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class DocxImportResult {
  final String deltaJson;
  final String plainText;
  final String suggestedTitle;
  final List<String> unsupportedElements;

  DocxImportResult({
    required this.deltaJson,
    required this.plainText,
    required this.suggestedTitle,
    this.unsupportedElements = const [],
  });
}

class DocxService {
  /// Imports a .docx file and converts its WordprocessingML content into Quill Delta JSON.
  static Future<DocxImportResult> importDocx(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('DOCX file not found', filePath);
    }

    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    ArchiveFile? docXmlFile;
    for (final f in archive) {
      if (f.name == 'word/document.xml') {
        docXmlFile = f;
        break;
      }
    }

    if (docXmlFile == null) {
      throw const FormatException('Invalid DOCX format: word/document.xml not found in archive');
    }

    final xmlContent = utf8.decode(docXmlFile.content as List<int>);
    final document = XmlDocument.parse(xmlContent);

    final List<Map<String, dynamic>> deltaOps = [];
    final StringBuffer plainTextBuf = StringBuffer();
    final List<String> unsupported = [];

    // Check for common advanced elements that may not be fully represented
    if (xmlContent.contains('<w:drawing') || xmlContent.contains('<v:shape')) {
      unsupported.add('Embedded vector drawings/shapes');
    }
    if (xmlContent.contains('<w:fldSimple') || xmlContent.contains('<w:instrText')) {
      unsupported.add('Complex Word calculation fields/macros');
    }
    if (xmlContent.contains('<w:smartTag')) {
      unsupported.add('Office SmartTags');
    }

    final body = document.findAllElements('w:body').firstOrNull;
    if (body == null) {
      return DocxImportResult(
        deltaJson: jsonEncode([{'insert': '\n'}]),
        plainText: '',
        suggestedTitle: _titleFromPath(filePath),
        unsupportedElements: unsupported,
      );
    }

    for (final child in body.children) {
      if (child is! XmlElement) continue;

      if (child.name.local == 'p') {
        _processParagraph(child, deltaOps, plainTextBuf);
      } else if (child.name.local == 'tbl') {
        _processTable(child, deltaOps, plainTextBuf);
      }
    }

    if (deltaOps.isEmpty) {
      deltaOps.add({'insert': '\n'});
    }

    // Ensure delta ends with newline
    final lastOp = deltaOps.last;
    if (lastOp['insert'] is String && !(lastOp['insert'] as String).endsWith('\n')) {
      deltaOps.add({'insert': '\n'});
    }

    return DocxImportResult(
      deltaJson: jsonEncode(deltaOps),
      plainText: plainTextBuf.toString(),
      suggestedTitle: _titleFromPath(filePath),
      unsupportedElements: unsupported,
    );
  }

  static void _processParagraph(
    XmlElement pElem,
    List<Map<String, dynamic>> ops,
    StringBuffer plainTextBuf,
  ) {
    Map<String, dynamic>? blockAttributes;

    // Check paragraph style (Headings, etc.)
    final pPr = pElem.findElements('w:pPr').firstOrNull;
    if (pPr != null) {
      final pStyle = pPr.findElements('w:pStyle').firstOrNull;
      if (pStyle != null) {
        final val = pStyle.getAttribute('w:val')?.toLowerCase() ?? '';
        if (val.contains('heading1') || val == '1' || val == 'title') {
          blockAttributes = {'header': 1};
        } else if (val.contains('heading2') || val == '2') {
          blockAttributes = {'header': 2};
        } else if (val.contains('heading3') || val == '3') {
          blockAttributes = {'header': 3};
        }
      }

      // Check alignment
      final jc = pPr.findElements('w:jc').firstOrNull;
      if (jc != null) {
        final align = jc.getAttribute('w:val');
        if (align == 'center') {
          blockAttributes = {...?blockAttributes, 'align': 'center'};
        } else if (align == 'right') {
          blockAttributes = {...?blockAttributes, 'align': 'right'};
        } else if (align == 'both' || align == 'justify') {
          blockAttributes = {...?blockAttributes, 'align': 'justify'};
        }
      }

      // Check list formatting
      final numPr = pPr.findElements('w:numPr').firstOrNull;
      if (numPr != null) {
        blockAttributes = {...?blockAttributes, 'list': 'bullet'};
      }
    }

    bool paragraphHasText = false;

    for (final rElem in pElem.findElements('w:r')) {
      final rPr = rElem.findElements('w:rPr').firstOrNull;
      final Map<String, dynamic> textAttributes = {};

      if (rPr != null) {
        if (rPr.findElements('w:b').isNotEmpty) textAttributes['bold'] = true;
        if (rPr.findElements('w:i').isNotEmpty) textAttributes['italic'] = true;
        if (rPr.findElements('w:u').isNotEmpty) textAttributes['underline'] = true;
        if (rPr.findElements('w:strike').isNotEmpty) textAttributes['strike'] = true;

        final colorElem = rPr.findElements('w:color').firstOrNull;
        if (colorElem != null) {
          final hex = colorElem.getAttribute('w:val');
          if (hex != null && hex != 'auto') {
            textAttributes['color'] = '#$hex';
          }
        }
      }

      for (final tElem in rElem.findElements('w:t')) {
        final text = tElem.innerText;
        if (text.isNotEmpty) {
          paragraphHasText = true;
          plainTextBuf.write(text);
          final Map<String, dynamic> op = {'insert': text};
          if (textAttributes.isNotEmpty) {
            op['attributes'] = textAttributes;
          }
          ops.add(op);
        }
      }
    }

    // Add newline with paragraph attributes
    final Map<String, dynamic> nlOp = {'insert': '\n'};
    if (blockAttributes != null) {
      nlOp['attributes'] = blockAttributes;
    }
    ops.add(nlOp);
    plainTextBuf.writeln();

    if (!paragraphHasText && blockAttributes == null) {
      // Empty paragraph handled
    }
  }

  static void _processTable(
    XmlElement tblElem,
    List<Map<String, dynamic>> ops,
    StringBuffer plainTextBuf,
  ) {
    plainTextBuf.writeln('--- Table ---');
    for (final tr in tblElem.findElements('w:tr')) {
      final List<String> rowCells = [];
      for (final tc in tr.findElements('w:tc')) {
        final StringBuffer cellBuf = StringBuffer();
        for (final p in tc.findElements('w:p')) {
          for (final t in p.findAllElements('w:t')) {
            cellBuf.write(t.innerText);
          }
        }
        rowCells.add(cellBuf.toString().trim());
      }
      final rowText = '| ${rowCells.join(' | ')} |';
      plainTextBuf.writeln(rowText);
      ops.add({'insert': '$rowText\n'});
    }
    plainTextBuf.writeln();
  }

  /// Generates the raw byte payload of a standard valid Microsoft Word (.docx) archive.
  static Future<Uint8List> generateDocxBytes({
    required String deltaJson,
    String title = 'Document',
  }) async {
    final List<dynamic> ops = jsonDecode(deltaJson) as List<dynamic>;

    final xmlBuffer = StringBuffer();
    xmlBuffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    xmlBuffer.writeln('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"');
    xmlBuffer.writeln('  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">');
    xmlBuffer.writeln('  <w:body>');

    // Parse delta into paragraphs
    final List<_ParagraphData> paragraphs = _groupIntoParagraphs(ops);

    for (final p in paragraphs) {
      xmlBuffer.writeln('    <w:p>');
      xmlBuffer.writeln('      <w:pPr>');
      if (p.headingLevel != null) {
        xmlBuffer.writeln('        <w:pStyle w:val="Heading${p.headingLevel}"/>');
      }
      if (p.alignment != null) {
        final alignVal = p.alignment == 'justify' ? 'both' : p.alignment;
        xmlBuffer.writeln('        <w:jc w:val="$alignVal"/>');
      }
      if (p.isBulletList) {
        xmlBuffer.writeln('        <w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr>');
      }
      xmlBuffer.writeln('      </w:pPr>');

      for (final run in p.runs) {
        xmlBuffer.writeln('      <w:r>');
        if (run.hasFormatting) {
          xmlBuffer.writeln('        <w:rPr>');
          if (run.isBold) xmlBuffer.writeln('          <w:b/>');
          if (run.isItalic) xmlBuffer.writeln('          <w:i/>');
          if (run.isUnderline) xmlBuffer.writeln('          <w:u w:val="single"/>');
          if (run.isStrike) xmlBuffer.writeln('          <w:strike/>');
          if (run.colorHex != null) {
            xmlBuffer.writeln('          <w:color w:val="${run.colorHex}"/>');
          }
          if (run.fontSizeHalfPoints != null) {
            xmlBuffer.writeln('          <w:sz w:val="${run.fontSizeHalfPoints}"/>');
          }
          xmlBuffer.writeln('        </w:rPr>');
        }
        final escapedText = _xmlEscape(run.text);
        xmlBuffer.writeln('        <w:t xml:space="preserve">$escapedText</w:t>');
        xmlBuffer.writeln('      </w:r>');
      }

      xmlBuffer.writeln('    </w:p>');
    }

    xmlBuffer.writeln('    <w:sectPr>');
    xmlBuffer.writeln('      <w:pgSz w:w="11906" w:h="16838"/>');
    xmlBuffer.writeln('      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/>');
    xmlBuffer.writeln('    </w:sectPr>');
    xmlBuffer.writeln('  </w:body>');
    xmlBuffer.writeln('</w:document>');

    final documentXmlBytes = utf8.encode(xmlBuffer.toString());

    // Build ZIP archive structure
    final archive = Archive();

    archive.addFile(ArchiveFile(
      '[Content_Types].xml',
      _contentTypesXml.length,
      utf8.encode(_contentTypesXml),
    ));

    archive.addFile(ArchiveFile(
      '_rels/.rels',
      _rootRelsXml.length,
      utf8.encode(_rootRelsXml),
    ));

    archive.addFile(ArchiveFile(
      'word/_rels/document.xml.rels',
      _docRelsXml.length,
      utf8.encode(_docRelsXml),
    ));

    archive.addFile(ArchiveFile(
      'word/styles.xml',
      _stylesXml.length,
      utf8.encode(_stylesXml),
    ));

    archive.addFile(ArchiveFile(
      'word/document.xml',
      documentXmlBytes.length,
      documentXmlBytes,
    ));

    final zipData = ZipEncoder().encode(archive);
    return Uint8List.fromList(zipData);
  }

  /// Exports Quill Delta JSON into a file at filePath.
  static Future<File> exportDocx({
    required String filePath,
    required String deltaJson,
    String title = 'Document',
  }) async {
    final bytes = await generateDocxBytes(deltaJson: deltaJson, title: title);
    final targetFile = File(filePath);
    await targetFile.writeAsBytes(bytes);
    return targetFile;
  }

  static List<_ParagraphData> _groupIntoParagraphs(List<dynamic> ops) {
    final List<_ParagraphData> paragraphs = [];
    List<_RunData> currentRuns = [];

    for (final op in ops) {
      if (op is! Map) continue;
      final insert = op['insert'];
      final attrs = op['attributes'] as Map<String, dynamic>? ?? {};

      if (insert is String) {
        final parts = insert.split('\n');
        for (int i = 0; i < parts.length; i++) {
          final part = parts[i];
          if (part.isNotEmpty) {
            currentRuns.add(_RunData.fromDelta(part, attrs));
          }

          if (i < parts.length - 1) {
            int? header;
            if (attrs['header'] != null) {
              header = (attrs['header'] as num).toInt();
            }
            String? align = attrs['align'] as String?;
            bool bullet = attrs['list'] == 'bullet' || attrs['list'] == 'ordered';

            paragraphs.add(_ParagraphData(
              runs: List.from(currentRuns),
              headingLevel: header,
              alignment: align,
              isBulletList: bullet,
            ));
            currentRuns.clear();
          }
        }
      }
    }

    if (currentRuns.isNotEmpty) {
      paragraphs.add(_ParagraphData(runs: currentRuns));
    }

    return paragraphs;
  }

  static String _xmlEscape(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _titleFromPath(String path) {
    final filename = path.split(RegExp(r'[\\/]')).last;
    if (filename.contains('.')) {
      return filename.substring(0, filename.lastIndexOf('.'));
    }
    return filename;
  }

  static const String _contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>''';

  static const String _rootRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

  static const String _docRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';

  static const String _stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/>
    <w:rPr>
      <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/>
      <w:sz w:val="22"/>
    </w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading1">
    <w:name w:val="heading 1"/>
    <w:basedOn w:val="Normal"/>
    <w:rPr>
      <w:rFonts w:ascii="Calibri Light" w:hAnsi="Calibri Light"/>
      <w:b/>
      <w:sz w:val="32"/>
      <w:color w:val="0F6CBD"/>
    </w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading2">
    <w:name w:val="heading 2"/>
    <w:basedOn w:val="Normal"/>
    <w:rPr>
      <w:rFonts w:ascii="Calibri Light" w:hAnsi="Calibri Light"/>
      <w:b/>
      <w:sz w:val="26"/>
      <w:color w:val="115EA3"/>
    </w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading3">
    <w:name w:val="heading 3"/>
    <w:basedOn w:val="Normal"/>
    <w:rPr>
      <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/>
      <w:b/>
      <w:sz w:val="24"/>
    </w:rPr>
  </w:style>
</w:styles>''';
}

class _ParagraphData {
  final List<_RunData> runs;
  final int? headingLevel;
  final String? alignment;
  final bool isBulletList;

  _ParagraphData({
    required this.runs,
    this.headingLevel,
    this.alignment,
    this.isBulletList = false,
  });
}

class _RunData {
  final String text;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final bool isStrike;
  final String? colorHex;
  final int? fontSizeHalfPoints;

  _RunData({
    required this.text,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.isStrike = false,
    this.colorHex,
    this.fontSizeHalfPoints,
  });

  bool get hasFormatting =>
      isBold || isItalic || isUnderline || isStrike || colorHex != null || fontSizeHalfPoints != null;

  factory _RunData.fromDelta(String text, Map<String, dynamic> attrs) {
    String? hex;
    if (attrs['color'] is String) {
      final c = attrs['color'] as String;
      hex = c.replaceAll('#', '').toUpperCase();
    }

    int? sz;
    if (attrs['size'] is num) {
      sz = ((attrs['size'] as num) * 2).round();
    }

    return _RunData(
      text: text,
      isBold: attrs['bold'] == true,
      isItalic: attrs['italic'] == true,
      isUnderline: attrs['underline'] == true,
      isStrike: attrs['strike'] == true,
      colorHex: hex,
      fontSizeHalfPoints: sz,
    );
  }
}
