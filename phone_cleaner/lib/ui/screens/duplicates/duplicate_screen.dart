import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/size_formatter.dart';
import '../../../data/models/duplicate_group.dart';
import '../../../providers/duplicate_scan_provider.dart';
import '../../../services/deletion_service.dart';
import '../../shared/widgets/confirmation_dialog.dart';

class DuplicateScreen extends ConsumerWidget {
  const DuplicateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(duplicateScanProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Duplicate Finder'),
        actions: [
          if (state is DuplicateScanning)
            TextButton(
              onPressed: () =>
                  ref.read(duplicateScanProvider.notifier).cancelScan(),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.danger)),
            ),
          if (state is DuplicateScanComplete || state is DuplicateScanDeleted)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () =>
                  ref.read(duplicateScanProvider.notifier).reset(),
            ),
        ],
      ),
      body: switch (state) {
        DuplicateScanIdle() => _IdleView(
            onScan: () =>
                ref.read(duplicateScanProvider.notifier).startScan(),
          ),
        DuplicateScanning(:final progress) =>
          _ScanningView(progress: progress),
        DuplicateScanComplete(:final groups) => _ResultsView(
            groups: groups,
            onDelete: (selectedGroups) async {
              final items =
                  selectedGroups.expand((g) => g.selectedForDeletion).toList();
              final totalBytes = items.fold(0, (s, f) => s + f.sizeBytes);
              final confirmed = await ConfirmationDialog.show(
                context,
                itemCount: items.length,
                totalBytes: totalBytes,
              );
              if (confirmed) {
                ref
                    .read(duplicateScanProvider.notifier)
                    .deleteSelected(selectedGroups);
              }
            },
          ),
        DuplicateScanDeleting() => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Deleting duplicates...',
                    style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        DuplicateScanDeleted(:final deletionResult) =>
          _DeletedView(result: deletionResult),
        DuplicateScanError(:final message) => _ErrorView(
            message: message,
            onRetry: () =>
                ref.read(duplicateScanProvider.notifier).startScan(),
          ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

// ── Idle ──────────────────────────────────────────────────────────────────────

class _IdleView extends StatelessWidget {
  final VoidCallback onScan;
  const _IdleView({required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.copy_all_rounded, size: 100, color: AppColors.secondary)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(end: 1.08, duration: 1200.ms, curve: Curves.easeInOut),
          const SizedBox(height: 32),
          const Text(
            'Find Duplicate Files',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Scan your storage to find duplicate photos, videos, and documents using content hashing.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 15),
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: onScan,
            icon: const Icon(Icons.search_rounded),
            label: const Text('Find Duplicates'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary),
          ),
        ],
      ),
    );
  }
}

// ── Scanning ──────────────────────────────────────────────────────────────────

class _ScanningView extends StatelessWidget {
  final DuplicateScanProgress progress;
  const _ScanningView({required this.progress});

  @override
  Widget build(BuildContext context) {
    final isHashing = progress.phase == 'hashing';
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.manage_search_rounded,
              size: 80, color: AppColors.secondary)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(end: 1.1, duration: 800.ms),
          const SizedBox(height: 32),
          Text(
            isHashing ? 'Comparing files...' : 'Collecting files...',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          LinearProgressIndicator(
            value: isHashing ? progress.percent : null,
            backgroundColor: AppColors.surfaceVariant,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
          ),
          const SizedBox(height: 12),
          if (isHashing)
            Text(
              '${progress.current} / ${progress.total} files hashed',
              style:
                  const TextStyle(color: AppColors.secondary, fontSize: 14),
            )
          else
            Text(
              '${progress.current} files collected',
              style:
                  const TextStyle(color: AppColors.secondary, fontSize: 14),
            ),
          const SizedBox(height: 8),
          Text(
            progress.currentPath,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Results ───────────────────────────────────────────────────────────────────

class _ResultsView extends StatefulWidget {
  final List<DuplicateGroup> groups;
  final void Function(List<DuplicateGroup>) onDelete;

  const _ResultsView({required this.groups, required this.onDelete});

  @override
  State<_ResultsView> createState() => _ResultsViewState();
}

class _ResultsViewState extends State<_ResultsView> {
  late Set<int> _selectedGroupIndices;

  @override
  void initState() {
    super.initState();
    _selectedGroupIndices =
        Set.from(List.generate(widget.groups.length, (i) => i));
  }

  int get _totalWasted {
    return _selectedGroupIndices
        .map((i) => widget.groups[i].wastedBytes)
        .fold(0, (s, v) => s + v);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 80, color: AppColors.primary),
            const SizedBox(height: 20),
            const Text('No duplicates found!',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('All files are unique.',
                style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    final totalWasted = widget.groups
        .fold(0, (s, g) => s + g.wastedBytes);

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.copy_all_rounded,
                  color: AppColors.secondary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${widget.groups.length} duplicate groups • ${SizeFormatter.format(totalWasted)} wasted',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.groups.length,
            itemBuilder: (context, index) {
              final group = widget.groups[index];
              final isSelected = _selectedGroupIndices.contains(index);
              return _DuplicateGroupTile(
                group: group,
                isSelected: isSelected,
                onToggle: () => setState(() {
                  if (isSelected) {
                    _selectedGroupIndices.remove(index);
                  } else {
                    _selectedGroupIndices.add(index);
                  }
                }),
              );
            },
          ),
        ),
        if (_selectedGroupIndices.isNotEmpty)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () {
                  final selected = _selectedGroupIndices
                      .map((i) => widget.groups[i])
                      .toList();
                  widget.onDelete(selected);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger),
                child: Text(
                  'Delete duplicates • ${SizeFormatter.format(_totalWasted)} to free',
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DuplicateGroupTile extends StatelessWidget {
  final DuplicateGroup group;
  final bool isSelected;
  final VoidCallback onToggle;

  const _DuplicateGroupTile({
    required this.group,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: Checkbox(
          value: isSelected,
          onChanged: (_) => onToggle(),
        ),
        title: Text(
          group.files.first.name,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${group.count} copies • ${SizeFormatter.format(group.sizeBytes)} each • ${SizeFormatter.format(group.wastedBytes)} wasted',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        children: [
          for (int i = 0; i < group.files.length; i++)
            ListTile(
              dense: true,
              leading: Icon(
                i == group.keepIndex
                    ? Icons.bookmark_rounded
                    : Icons.delete_outline_rounded,
                color: i == group.keepIndex
                    ? AppColors.primary
                    : AppColors.danger,
                size: 20,
              ),
              title: Text(
                group.files[i].path,
                style: TextStyle(
                  color: i == group.keepIndex
                      ? AppColors.primary
                      : Colors.white70,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                i == group.keepIndex ? 'Keep (oldest)' : 'Will be deleted',
                style: TextStyle(
                  color: i == group.keepIndex
                      ? Colors.white38
                      : AppColors.danger.withOpacity(0.7),
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Deleted ───────────────────────────────────────────────────────────────────

class _DeletedView extends StatelessWidget {
  final DeletionResult result;
  const _DeletedView({required this.result});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 80, color: AppColors.primary)
              .animate()
              .scale(begin: const Offset(0, 0))
              .fadeIn(),
          const SizedBox(height: 24),
          const Text(
            'Duplicates Removed!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${result.deletedCount} duplicate${result.deletedCount == 1 ? '' : 's'} deleted\n${SizeFormatter.format(result.freedBytes)} freed',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

// ── Error ─────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 60, color: AppColors.danger),
          const SizedBox(height: 16),
          const Text(
            'Scan failed',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onRetry,
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
