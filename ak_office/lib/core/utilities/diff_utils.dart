enum DiffType { insertion, deletion, unchanged }

class DiffSegment {
  final DiffType type;
  final String text;

  const DiffSegment({required this.type, required this.text});
}

class DiffUtils {
  /// Simple diff between two strings splitting by word or line for visualization
  static List<DiffSegment> computeWordDiff(String original, String modified) {
    if (original == modified) {
      return [DiffSegment(type: DiffType.unchanged, text: original)];
    }

    final originalWords = original.split(RegExp(r'(\s+)'));
    final modifiedWords = modified.split(RegExp(r'(\s+)'));

    final List<DiffSegment> segments = [];
    int oIndex = 0;
    int mIndex = 0;

    while (oIndex < originalWords.length && mIndex < modifiedWords.length) {
      if (originalWords[oIndex] == modifiedWords[mIndex]) {
        segments.add(DiffSegment(type: DiffType.unchanged, text: originalWords[oIndex]));
        oIndex++;
        mIndex++;
      } else {
        // Look ahead for match
        int nextOInM = -1;
        for (int i = mIndex; i < modifiedWords.length && i < mIndex + 5; i++) {
          if (originalWords[oIndex] == modifiedWords[i]) {
            nextOInM = i;
            break;
          }
        }

        if (nextOInM != -1) {
          // Words between mIndex and nextOInM were inserted
          for (int i = mIndex; i < nextOInM; i++) {
            segments.add(DiffSegment(type: DiffType.insertion, text: modifiedWords[i]));
          }
          mIndex = nextOInM;
        } else {
          // Current word in original was deleted or replaced
          segments.add(DiffSegment(type: DiffType.deletion, text: originalWords[oIndex]));
          oIndex++;
          if (mIndex < modifiedWords.length) {
            segments.add(DiffSegment(type: DiffType.insertion, text: modifiedWords[mIndex]));
            mIndex++;
          }
        }
      }
    }

    while (oIndex < originalWords.length) {
      segments.add(DiffSegment(type: DiffType.deletion, text: originalWords[oIndex]));
      oIndex++;
    }

    while (mIndex < modifiedWords.length) {
      segments.add(DiffSegment(type: DiffType.insertion, text: modifiedWords[mIndex]));
      mIndex++;
    }

    return segments;
  }
}
