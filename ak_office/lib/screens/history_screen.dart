import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_constants.dart';
import '../models/activity_model.dart';
import '../models/document_model.dart';
import '../models/revision_model.dart';
import '../repositories/activity_repository.dart';
import '../repositories/revision_repository.dart';
import '../services/document_service.dart';

class HistoryScreen extends StatefulWidget {
  final DocumentModel? document;
  final Function(String restoredDelta)? onVersionRestored;

  const HistoryScreen({
    super.key,
    this.document,
    this.onVersionRestored,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final RevisionRepository _revisionRepo = RevisionRepository();
  final ActivityRepository _activityRepo = ActivityRepository();
  final DocumentService _docService = DocumentService();

  List<RevisionModel> _revisions = [];
  List<ActivityModel> _activities = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    if (widget.document != null) {
      final revs = await _revisionRepo.getRevisionsForDocument(widget.document!.id);
      final acts = await _activityRepo.getActivitiesForDocument(widget.document!.id);
      if (mounted) {
        setState(() {
          _revisions = revs;
          _activities = acts;
          _isLoading = false;
        });
      }
    } else {
      final acts = await _activityRepo.getAllActivities(limit: 100);
      if (mounted) {
        setState(() {
          _activities = acts;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _restoreRevision(RevisionModel rev) async {
    if (widget.document == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Restore Revision #${rev.versionNumber}?'),
        content: Text(
          'Are you sure you want to revert "${widget.document!.title}" to Version ${rev.versionNumber} '
          '(${DateFormat('MMM d, h:mm a').format(rev.timestamp)})?\n\n'
          'Current unsaved changes will be replaced with this version snapshot.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.wordBlue, foregroundColor: Colors.white),
            child: const Text('Restore Version'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final restoredDelta = await _docService.restoreRevision(widget.document!, rev);
        widget.onVersionRestored?.call(restoredDelta);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully restored Revision #${rev.versionNumber}')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to restore version: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.document != null ? 'History: ${widget.document!.title}' : 'Application Activity Log';

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppConstants.wordBlue,
          indicatorColor: AppConstants.wordBlue,
          tabs: [
            Tab(
              icon: const Icon(Icons.history, size: 18),
              text: 'Revisions (${_revisions.length})',
            ),
            Tab(
              icon: const Icon(Icons.receipt_long, size: 18),
              text: 'Activity Audit (${_activities.length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRevisionsTab(),
                _buildActivitiesTab(),
              ],
            ),
    );
  }

  Widget _buildRevisionsTab() {
    if (widget.document == null) {
      return const Center(child: Text('Open a document to inspect its revision history.'));
    }

    if (_revisions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_toggle_off, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            const Text('No revisions recorded yet.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            const Text('Revisions are created automatically whenever you save versions.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _revisions.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final rev = _revisions[index];
        final isLatest = index == 0;

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: isLatest ? AppConstants.wordBlue : Colors.grey.shade200,
            foregroundColor: isLatest ? Colors.white : Colors.black87,
            child: Text('v${rev.versionNumber}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          title: Row(
            children: [
              Text(
                'Version ${rev.versionNumber}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              if (isLatest) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppConstants.wordLightBlue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Latest', style: TextStyle(fontSize: 10, color: AppConstants.wordDarkBlue, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(rev.summary, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 2),
              Text(
                '${DateFormat('MMM d, yyyy h:mm:ss a').format(rev.timestamp)} • ${rev.wordCount} words',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          trailing: OutlinedButton.icon(
            icon: const Icon(Icons.restore, size: 14),
            label: const Text('Restore', style: TextStyle(fontSize: 11)),
            onPressed: () => _restoreRevision(rev),
          ),
        );
      },
    );
  }

  Widget _buildActivitiesTab() {
    final filtered = _searchQuery.isEmpty
        ? _activities
        : _activities.where((a) {
            return a.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (a.documentTitle?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
          }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Filter activity log...',
                    prefixIcon: Icon(Icons.search, size: 18),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: 'Clear activity log',
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Clear Activity Records?'),
                      content: const Text(
                        'This will delete the local activity log records. '
                        'No documents will be affected.',
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                          child: const Text('Clear Records'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await _activityRepo.clearActivities(documentId: widget.document?.id);
                    await _loadData();
                  }
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No activity records found.', style: TextStyle(color: Colors.grey)))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final a = filtered[index];
                    return ListTile(
                      dense: true,
                      leading: _buildActivityIcon(a.eventType),
                      title: Text(a.description, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${DateFormat('MMM d, yyyy h:mm:ss a').format(a.timestamp)}'
                        '${a.documentTitle != null ? ' • ${a.documentTitle}' : ''}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildActivityIcon(ActivityEventType type) {
    IconData icon;
    Color color;

    switch (type) {
      case ActivityEventType.documentCreated:
        icon = Icons.add_circle_outline;
        color = Colors.green;
        break;
      case ActivityEventType.documentOpened:
        icon = Icons.folder_open;
        color = AppConstants.wordBlue;
        break;
      case ActivityEventType.documentSaved:
        icon = Icons.save;
        color = Colors.blueGrey;
        break;
      case ActivityEventType.aiSuggestionAccepted:
        icon = Icons.auto_awesome;
        color = Colors.teal;
        break;
      case ActivityEventType.aiSuggestionRejected:
        icon = Icons.auto_awesome_motion;
        color = Colors.grey;
        break;
      case ActivityEventType.documentExported:
        icon = Icons.upload_file;
        color = Colors.purple;
        break;
      case ActivityEventType.versionRestored:
        icon = Icons.restore;
        color = Colors.amber.shade800;
        break;
      case ActivityEventType.documentDeleted:
        icon = Icons.delete;
        color = Colors.red;
        break;
      default:
        icon = Icons.edit_note;
        color = Colors.blue;
    }

    return Icon(icon, size: 18, color: color);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
