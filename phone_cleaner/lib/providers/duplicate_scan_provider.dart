import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/duplicate_group.dart';
import '../services/deletion_service.dart';
import '../services/duplicate_finder_service.dart';
import 'storage_provider.dart';

// ── State ─────────────────────────────────────────────────────────────────────

sealed class DuplicateScanState {
  const DuplicateScanState();
}

class DuplicateScanIdle extends DuplicateScanState {
  const DuplicateScanIdle();
}

class DuplicateScanning extends DuplicateScanState {
  final DuplicateScanProgress progress;
  const DuplicateScanning(this.progress);
}

class DuplicateScanComplete extends DuplicateScanState {
  final List<DuplicateGroup> groups;
  const DuplicateScanComplete(this.groups);
}

class DuplicateScanDeleting extends DuplicateScanState {
  final List<DuplicateGroup> groups;
  const DuplicateScanDeleting(this.groups);
}

class DuplicateScanDeleted extends DuplicateScanState {
  final DeletionResult deletionResult;
  const DuplicateScanDeleted(this.deletionResult);
}

class DuplicateScanError extends DuplicateScanState {
  final String message;
  const DuplicateScanError(this.message);
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class DuplicateScanNotifier extends StateNotifier<DuplicateScanState> {
  final Ref _ref;
  DuplicateFinderService? _service;

  DuplicateScanNotifier(this._ref) : super(const DuplicateScanIdle());

  Future<void> startScan() async {
    state = DuplicateScanning(
      const DuplicateScanProgress(
        phase: 'collecting',
        current: 0,
        total: 0,
        currentPath: '',
      ),
    );
    _service = DuplicateFinderService();

    try {
      final roots = await _ref.read(storageServiceProvider).getStorageRoots();
      await for (final progress in _service!.findDuplicates(roots)) {
        if (!mounted) return;
        state = DuplicateScanning(progress);
      }
      if (!mounted) return;
      final groups = _service!.getDuplicateGroups();
      state = DuplicateScanComplete(groups);
    } catch (e) {
      if (mounted) state = DuplicateScanError(e.toString());
    }
  }

  void cancelScan() {
    _service?.cancel();
    state = const DuplicateScanIdle();
  }

  void reset() => state = const DuplicateScanIdle();

  Future<void> deleteSelected(List<DuplicateGroup> groups) async {
    final current = state;
    if (current is! DuplicateScanComplete) return;

    state = DuplicateScanDeleting(current.groups);

    final items = groups.expand((g) => g.selectedForDeletion).toList();
    try {
      final result = await DeletionService().deleteItems(items);
      if (!mounted) return;
      state = DuplicateScanDeleted(result);
      _ref.invalidate(storageInfoProvider);
    } catch (e) {
      if (mounted) state = DuplicateScanError(e.toString());
    }
  }
}

final duplicateScanProvider =
    StateNotifierProvider<DuplicateScanNotifier, DuplicateScanState>(
  (ref) => DuplicateScanNotifier(ref),
);
