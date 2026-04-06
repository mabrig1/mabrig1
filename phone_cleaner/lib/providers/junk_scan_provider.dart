import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/file_item.dart';
import '../data/models/scan_result.dart';
import '../services/deletion_service.dart';
import '../services/file_scanner_service.dart';
import 'storage_provider.dart';

// ── State ─────────────────────────────────────────────────────────────────────

sealed class JunkScanState {
  const JunkScanState();
}

class JunkScanIdle extends JunkScanState {
  const JunkScanIdle();
}

class JunkScanScanning extends JunkScanState {
  final ScanProgress progress;
  const JunkScanScanning(this.progress);
}

class JunkScanComplete extends JunkScanState {
  final ScanResult result;
  const JunkScanComplete(this.result);
}

class JunkScanDeleting extends JunkScanState {
  final ScanResult result;
  const JunkScanDeleting(this.result);
}

class JunkScanDeleted extends JunkScanState {
  final DeletionResult deletionResult;
  const JunkScanDeleted(this.deletionResult);
}

class JunkScanError extends JunkScanState {
  final String message;
  const JunkScanError(this.message);
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class JunkScanNotifier extends StateNotifier<JunkScanState> {
  final Ref _ref;
  FileScannerService? _scanner;
  final DateTime _startTime = DateTime.now();

  JunkScanNotifier(this._ref) : super(const JunkScanIdle());

  Future<void> startScan() async {
    state = JunkScanScanning(
      ScanProgress(currentPath: '', filesFound: 0, bytesFound: 0),
    );
    _scanner = FileScannerService();
    final start = DateTime.now();

    try {
      final roots = await _ref.read(storageServiceProvider).getStorageRoots();
      await for (final progress in _scanner!.scanForJunk(roots)) {
        if (!mounted) return;
        state = JunkScanScanning(progress);
      }
      if (!mounted) return;
      final duration = DateTime.now().difference(start);
      state = JunkScanComplete(_scanner!.buildResult(duration));
    } catch (e) {
      if (mounted) state = JunkScanError(e.toString());
    }
  }

  void cancelScan() {
    _scanner?.cancel();
    state = const JunkScanIdle();
  }

  void reset() => state = const JunkScanIdle();

  void toggleItem(String path) {
    final current = state;
    if (current is! JunkScanComplete) return;
    final items = current.result.items.map((item) {
      if (item.path == path) return item.copyWith(isSelected: !item.isSelected);
      return item;
    }).toList();
    state = JunkScanComplete(
      ScanResult(
        items: items,
        scannedAt: current.result.scannedAt,
        scanDuration: current.result.scanDuration,
      ),
    );
  }

  void toggleCategory(JunkCategory category, bool selected) {
    final current = state;
    if (current is! JunkScanComplete) return;
    final items = current.result.items.map((item) {
      if (item.category == category) return item.copyWith(isSelected: selected);
      return item;
    }).toList();
    state = JunkScanComplete(
      ScanResult(
        items: items,
        scannedAt: current.result.scannedAt,
        scanDuration: current.result.scanDuration,
      ),
    );
  }

  void selectAll(bool selected) {
    final current = state;
    if (current is! JunkScanComplete) return;
    final items = current.result.items
        .map((item) => item.copyWith(isSelected: selected))
        .toList();
    state = JunkScanComplete(
      ScanResult(
        items: items,
        scannedAt: current.result.scannedAt,
        scanDuration: current.result.scanDuration,
      ),
    );
  }

  Future<void> deleteSelected() async {
    final current = state;
    if (current is! JunkScanComplete) return;

    final selected =
        current.result.items.where((i) => i.isSelected).toList();
    if (selected.isEmpty) return;

    state = JunkScanDeleting(current.result);

    try {
      final result = await DeletionService().deleteItems(selected);
      if (!mounted) return;
      state = JunkScanDeleted(result);
      // Refresh storage gauge
      _ref.invalidate(storageInfoProvider);
    } catch (e) {
      if (mounted) state = JunkScanError(e.toString());
    }
  }
}

final junkScanProvider =
    StateNotifierProvider<JunkScanNotifier, JunkScanState>(
  (ref) => JunkScanNotifier(ref),
);
