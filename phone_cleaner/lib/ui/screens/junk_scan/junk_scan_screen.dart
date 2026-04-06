import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/size_formatter.dart';
import '../../../data/models/file_item.dart';
import '../../../providers/junk_scan_provider.dart';
import '../../../services/deletion_service.dart';
import '../../shared/widgets/confirmation_dialog.dart';

class JunkScanScreen extends ConsumerWidget {
  const JunkScanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(junkScanProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Junk Cleaner'),
        actions: [
          if (state is JunkScanScanning)
            TextButton(
              onPressed: () => ref.read(junkScanProvider.notifier).cancelScan(),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.danger)),
            ),
          if (state is JunkScanComplete || state is JunkScanDeleted)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.read(junkScanProvider.notifier).reset(),
            ),
        ],
      ),
      body: switch (state) {
        JunkScanIdle() => _IdleView(
            onScan: () => ref.read(junkScanProvider.notifier).startScan(),
          ),
        JunkScanScanning(:final progress) => _ScanningView(progress: progress),
        JunkScanComplete(:final result) => _ResultsView(
            result: result,
            onDelete: () async {
              final selected =
                  result.items.where((i) => i.isSelected).toList();
              if (selected.isEmpty) return;
              final totalBytes =
                  selected.fold(0, (s, f) => s + f.sizeBytes);
              final confirmed = await ConfirmationDialog.show(
                context,
                itemCount: selected.length,
                totalBytes: totalBytes,
              );
              if (confirmed) {
                ref.read(junkScanProvider.notifier).deleteSelected();
              }
            },
            onToggleItem: (path) =>
                ref.read(junkScanProvider.notifier).toggleItem(path),
            onToggleCategory: (cat, sel) =>
                ref.read(junkScanProvider.notifier).toggleCategory(cat, sel),
            onSelectAll: (sel) =>
                ref.read(junkScanProvider.notifier).selectAll(sel),
          ),
        JunkScanDeleting() => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Cleaning...', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        JunkScanDeleted(:final deletionResult) =>
          _DeletedView(result: deletionResult),
        JunkScanError(:final message) => _ErrorView(
            message: message,
            onRetry: () => ref.read(junkScanProvider.notifier).startScan(),
          ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

// ── Idle View ─────────────────────────────────────────────────────────────────

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
          const Icon(
            Icons.cleaning_services_rounded,
            size: 100,
            color: AppColors.primary,
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(end: 1.08, duration: 1200.ms, curve: Curves.easeInOut),
          const SizedBox(height: 32),
          const Text(
            'Scan for Junk Files',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Find and remove app caches, temp files, logs, and empty folders.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 15),
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: onScan,
            icon: const Icon(Icons.search_rounded),
            label: const Text('Start Scan'),
          ),
        ],
      ),
    );
  }
}

// ── Scanning View ─────────────────────────────────────────────────────────────

class _ScanningView extends StatelessWidget {
  final ScanProgress progress;
  const _ScanningView({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.radar_rounded, size: 80, color: AppColors.primary)
              .animate(onPlay: (c) => c.repeat())
              .rotate(duration: 2.seconds),
          const SizedBox(height: 32),
          const Text(
            'Scanning...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          LinearProgressIndicator(
            backgroundColor: AppColors.surfaceVariant,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            '${progress.filesFound} files found • ${SizeFormatter.format(progress.bytesFound)}',
            style: const TextStyle(color: AppColors.primary, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            progress.currentPath.isNotEmpty ? progress.currentPath : '',
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

// ── Results View ──────────────────────────────────────────────────────────────

class _ResultsView extends ConsumerWidget {
  final dynamic result;
  final VoidCallback onDelete;
  final void Function(String) onToggleItem;
  final void Function(JunkCategory, bool) onToggleCategory;
  final void Function(bool) onSelectAll;

  const _ResultsView({
    required this.result,
    required this.onDelete,
    required this.onToggleItem,
    required this.onToggleCategory,
    required this.onSelectAll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(junkScanProvider);
    if (state is! JunkScanComplete) return const SizedBox.shrink();
    final scanResult = state.result;

    if (scanResult.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 80, color: AppColors.primary),
            const SizedBox(height: 20),
            const Text(
              'Your phone is clean!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('No junk files found.',
                style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    final byCategory = scanResult.byCategory;
    final selected = scanResult.items.where((i) => i.isSelected).toList();
    final selectedBytes = selected.fold(0, (s, f) => s + f.sizeBytes);
    final allSelected =
        scanResult.items.isNotEmpty && scanResult.items.every((i) => i.isSelected);

    return Column(
      children: [
        // Summary bar
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: AppColors.warning, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${scanResult.fileCount} items • ${SizeFormatter.format(scanResult.totalSizeBytes)} found',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              TextButton(
                onPressed: () => onSelectAll(!allSelected),
                child: Text(allSelected ? 'Deselect All' : 'Select All',
                    style: const TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
        ),
        // Category list
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: byCategory.entries.map((entry) {
              return _CategoryTile(
                category: entry.key,
                items: entry.value,
                onToggleItem: onToggleItem,
                onToggleCategory: onToggleCategory,
              );
            }).toList(),
          ),
        ),
        // Bottom action bar
        if (selected.isNotEmpty)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: onDelete,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger),
                child: Text(
                  'Clean ${selected.length} item${selected.length == 1 ? '' : 's'} • ${SizeFormatter.format(selectedBytes)}',
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final JunkCategory category;
  final List<FileItem> items;
  final void Function(String) onToggleItem;
  final void Function(JunkCategory, bool) onToggleCategory;

  const _CategoryTile({
    required this.category,
    required this.items,
    required this.onToggleItem,
    required this.onToggleCategory,
  });

  Color get _categoryColor {
    return switch (category) {
      JunkCategory.appCache => AppColors.categoryCache,
      JunkCategory.thumbnails => AppColors.categoryThumbnail,
      JunkCategory.tempFiles => AppColors.categoryTemp,
      JunkCategory.logFiles => AppColors.categoryLog,
      JunkCategory.obsoleteApks => AppColors.categoryApk,
      JunkCategory.emptyDirectories => AppColors.categoryEmpty,
    };
  }

  IconData get _categoryIcon {
    return switch (category) {
      JunkCategory.appCache => Icons.cached_rounded,
      JunkCategory.thumbnails => Icons.image_not_supported_rounded,
      JunkCategory.tempFiles => Icons.file_copy_outlined,
      JunkCategory.logFiles => Icons.article_outlined,
      JunkCategory.obsoleteApks => Icons.android_rounded,
      JunkCategory.emptyDirectories => Icons.folder_off_rounded,
    };
  }

  int get _totalBytes => items.fold(0, (s, f) => s + f.sizeBytes);
  bool get _allSelected => items.every((i) => i.isSelected);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _categoryColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_categoryIcon, color: _categoryColor, size: 22),
        ),
        title: Text(
          category.label,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${items.length} files • ${SizeFormatter.format(_totalBytes)}',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: _allSelected,
              onChanged: (v) => onToggleCategory(category, v ?? false),
            ),
          ],
        ),
        children: items.map((item) {
          return ListTile(
            dense: true,
            leading: Checkbox(
              value: item.isSelected,
              onChanged: (_) => onToggleItem(item.path),
            ),
            title: Text(
              item.name,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              item.path,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              SizeFormatter.format(item.sizeBytes),
              style:
                  const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Deleted View ──────────────────────────────────────────────────────────────

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
              .scale(begin: const Offset(0, 0), end: const Offset(1, 1))
              .fadeIn(),
          const SizedBox(height: 24),
          const Text(
            'Cleaned!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${result.deletedCount} file${result.deletedCount == 1 ? '' : 's'} removed\n${SizeFormatter.format(result.freedBytes)} freed',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          if (result.hasErrors) ...[
            const SizedBox(height: 12),
            Text(
              '${result.failedPaths.length} file${result.failedPaths.length == 1 ? '' : 's'} could not be deleted.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.warning, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Error View ────────────────────────────────────────────────────────────────

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
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
