import 'dart:convert';

class DocumentOutlineItem {
  final int level;
  final String title;
  final int offset;

  DocumentOutlineItem({
    required this.level,
    required this.title,
    required this.offset,
  });
}

class DocumentContextService {
  /// Extracts headings hierarchy and document outline from Quill Delta JSON.
  static List<DocumentOutlineItem> extractOutline(String deltaJson) {
    final List<DocumentOutlineItem> outline = [];
    try {
      final List<dynamic> ops = jsonDecode(deltaJson) as List<dynamic>;
      int currentOffset = 0;
      final StringBuffer lineBuffer = StringBuffer();

      for (final op in ops) {
        if (op is! Map) continue;
        final insert = op['insert'];
        final attrs = op['attributes'] as Map<String, dynamic>? ?? {};

        if (insert is String) {
          final parts = insert.split('\n');
          for (int i = 0; i < parts.length; i++) {
            lineBuffer.write(parts[i]);
            currentOffset += parts[i].length;

            if (i < parts.length - 1) {
              // Line ended
              final headerVal = attrs['header'];
              if (headerVal != null) {
                final lvl = (headerVal as num).toInt();
                final text = lineBuffer.toString().trim();
                if (text.isNotEmpty) {
                  outline.add(DocumentOutlineItem(
                    level: lvl,
                    title: text,
                    offset: currentOffset - text.length,
                  ));
                }
              }
              lineBuffer.clear();
              currentOffset += 1; // Newline char
            }
          }
        }
      }
    } catch (_) {}
    return outline;
  }

  /// Extracts paragraphs and structure
  static List<String> extractParagraphs(String plainText) {
    return plainText
        .split(RegExp(r'\n+'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
  }

  /// Extracts key sentences based on word frequency scoring (TF heuristic)
  static List<String> extractKeySentences(String text, {int count = 4}) {
    final sentences = text
        .split(RegExp(r'(?<=[.?!])\s+'))
        .map((s) => s.trim())
        .where((s) => s.length > 20)
        .toList();

    if (sentences.length <= count) return sentences;

    // Word frequency map
    final words = text.toLowerCase().split(RegExp(r'[^a-zA-Z0-9]+'));
    final freq = <String, int>{};
    for (final w in words) {
      if (w.length > 3 && !_stopWords.contains(w)) {
        freq[w] = (freq[w] ?? 0) + 1;
      }
    }

    // Score sentences
    final scored = sentences.map((s) {
      double score = 0;
      final sWords = s.toLowerCase().split(RegExp(r'[^a-zA-Z0-9]+'));
      for (final sw in sWords) {
        score += freq[sw] ?? 0;
      }
      return MapEntry(s, score / (sWords.isNotEmpty ? sWords.length : 1));
    }).toList();

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(count).map((e) => e.key).toList();
  }

  static const Set<String> _stopWords = {
    'this', 'that', 'with', 'from', 'have', 'were', 'will', 'your', 'their',
    'which', 'there', 'about', 'these', 'would', 'could', 'should', 'other',
    'into', 'some', 'than', 'them', 'they', 'what', 'when', 'where', 'while'
  };
}
