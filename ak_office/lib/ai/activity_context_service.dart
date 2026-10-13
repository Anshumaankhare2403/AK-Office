import 'package:intl/intl.dart';
import '../models/activity_model.dart';
import '../models/document_model.dart';
import '../models/revision_model.dart';

class ActivityContextService {
  /// Answers questions regarding application and document activity history.
  static String? answerActivityQuery({
    required String query,
    required DocumentModel? currentDoc,
    required List<ActivityModel> activities,
    required List<RevisionModel> revisions,
  }) {
    final q = query.toLowerCase().trim();

    // 1. "What did I do today?"
    if (q.contains('today') && (q.contains('what did') || q.contains('work') || q.contains('do'))) {
      final now = DateTime.now();
      final todayActivities = activities.where((a) {
        return a.timestamp.year == now.year &&
            a.timestamp.month == now.month &&
            a.timestamp.day == now.day;
      }).toList();

      if (todayActivities.isEmpty) {
        return 'No logged application activity recorded yet for today.';
      }

      final buf = StringBuffer('Here is a summary of your activity in DocuCraft today:\n\n');
      for (final a in todayActivities.take(10)) {
        final timeStr = DateFormat('h:mm a').format(a.timestamp);
        buf.writeln('• **$timeStr**: ${a.description}');
      }
      return buf.toString();
    }

    // 2. "Which documents did I edit recently?"
    if (q.contains('which document') || q.contains('recent documents') || (q.contains('edit') && q.contains('recently'))) {
      final editedDocs = <String>{};
      final buf = StringBuffer('Recently modified documents based on local activity log:\n\n');
      for (final a in activities) {
        if (a.documentTitle != null && !editedDocs.contains(a.documentTitle)) {
          editedDocs.add(a.documentTitle!);
          final dateStr = DateFormat('MMM d, h:mm a').format(a.timestamp);
          buf.writeln('• **${a.documentTitle}** — last recorded event on $dateStr');
          if (editedDocs.length >= 8) break;
        }
      }
      return editedDocs.isEmpty ? 'No recent document edits recorded.' : buf.toString();
    }

    // 3. "When was this document last saved?"
    if (q.contains('last save') || (q.contains('saved') && q.contains('when'))) {
      if (currentDoc == null) {
        return 'No document is currently active.';
      }
      final dateStr = DateFormat('MMM d, yyyy at h:mm:ss a').format(currentDoc.updatedAt);
      return 'The current document **"${currentDoc.title}"** was last saved on **$dateStr**.';
    }

    // 4. "Which AI suggestions did I accept?"
    if (q.contains('suggestion') && (q.contains('accept') || q.contains('accepted'))) {
      final accepted = activities
          .where((a) => a.eventType == ActivityEventType.aiSuggestionAccepted)
          .toList();

      if (accepted.isEmpty) {
        return 'No AI suggestions have been accepted yet in this document.';
      }

      final buf = StringBuffer('You have accepted the following AI suggestions:\n\n');
      for (final a in accepted.take(8)) {
        final dateStr = DateFormat('MMM d, h:mm a').format(a.timestamp);
        buf.writeln('• **$dateStr**: ${a.description}');
      }
      return buf.toString();
    }

    // 5. "What changes did I make to this document?" or "Summarize the work I completed"
    if ((q.contains('changes') || q.contains('work')) && (q.contains('this document') || q.contains('completed') || q.contains('make'))) {
      if (currentDoc == null) return 'No document is currently open.';
      final docActivities = activities.where((a) => a.documentId == currentDoc.id).toList();

      final buf = StringBuffer('Summary of work completed on **"${currentDoc.title}"**:\n\n');
      buf.writeln('• Current word count: **${currentDoc.wordCount} words** (${currentDoc.characterCount} characters)');
      buf.writeln('• Created: ${DateFormat('MMM d, yyyy h:mm a').format(currentDoc.createdAt)}');
      buf.writeln('• Total recorded revisions: ${revisions.length}');
      buf.writeln('\n**Recent Activity Trail:**');

      if (docActivities.isEmpty) {
        buf.writeln('• No specific modification events logged yet.');
      } else {
        for (final a in docActivities.take(6)) {
          final timeStr = DateFormat('MMM d, h:mm a').format(a.timestamp);
          buf.writeln('• $timeStr — ${a.description}');
        }
      }
      return buf.toString();
    }

    // 6. "Compare with earlier version" or "revisions"
    if (q.contains('version') || q.contains('revision') || q.contains('earlier')) {
      if (revisions.isEmpty) {
        return 'No previous revisions found for this document yet.';
      }
      final buf = StringBuffer('Available revisions for **"${currentDoc?.title ?? 'Document'}"**:\n\n');
      for (final r in revisions) {
        final timeStr = DateFormat('MMM d, h:mm a').format(r.timestamp);
        buf.writeln('• **Revision #${r.versionNumber}** ($timeStr): ${r.summary} (${r.wordCount} words)');
      }
      buf.writeln('\nYou can inspect or restore any version in the History panel.');
      return buf.toString();
    }

    return null; // Not an activity question
  }
}
