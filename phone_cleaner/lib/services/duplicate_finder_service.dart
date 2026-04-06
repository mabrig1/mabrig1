import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/junk_paths.dart';
import '../data/models/duplicate_group.dart';
import '../data/models/file_item.dart';

class DuplicateScanProgress {
  final String phase; // 'collecting' | 'hashing'
  final int current;
  final int total;
  final String currentPath;

  const DuplicateScanProgress({
    required this.phase,
    required this.current,
    required this.total,
    required this.currentPath,
  });

  double get percent => total > 0 ? current / total : 0;
}

class DuplicateFinderService {
  bool _cancelled = false;

  void cancel() => _cancelled = true;

  Stream<DuplicateScanProgress> findDuplicates(
    List<Directory> roots, {
    int minSizeBytes = kMinDuplicateSizeBytes,
  }) async* {
    _cancelled = false;

    // Phase 1: Collect all files, group by size
    final Map<int, List<File>> bySize = {};
    int collected = 0;

    for (final root in roots) {
      if (_cancelled) return;
      try {
        await for (final entity in root.list(recursive: true, followLinks: false)) {
          if (_cancelled) return;
          if (entity is File) {
            try {
              final stat = await entity.stat();
              if (stat.size >= minSizeBytes) {
                bySize.putIfAbsent(stat.size, () => []).add(entity as File);
                collected++;
                yield DuplicateScanProgress(
                  phase: 'collecting',
                  current: collected,
                  total: collected,
                  currentPath: entity.path,
                );
              }
            } catch (_) {}
          }
        }
      } catch (_) {}
    }

    if (_cancelled) return;

    // Phase 2: Hash only files that share a size with at least one other file
    final candidates = bySize.entries
        .where((e) => e.value.length > 1)
        .expand((e) => e.value)
        .toList();

    final Map<String, List<File>> byHash = {};

    for (int i = 0; i < candidates.length; i++) {
      if (_cancelled) return;
      final file = candidates[i];
      yield DuplicateScanProgress(
        phase: 'hashing',
        current: i + 1,
        total: candidates.length,
        currentPath: file.path,
      );
      try {
        final hash = await compute(_hashFile, file.path);
        byHash.putIfAbsent(hash, () => []).add(file);
      } catch (_) {}
    }

    // Store result (consumed by provider via getDuplicateGroups)
    _lastGroups = await _buildGroups(byHash);
  }

  List<DuplicateGroup> _lastGroups = [];

  List<DuplicateGroup> getDuplicateGroups() => _lastGroups;

  Future<List<DuplicateGroup>> _buildGroups(
    Map<String, List<File>> byHash,
  ) async {
    final groups = <DuplicateGroup>[];
    for (final entry in byHash.entries) {
      if (entry.value.length < 2) continue;
      final items = <FileItem>[];
      for (final file in entry.value) {
        try {
          final item = await FileItem.fromFile(file);
          items.add(item);
        } catch (_) {}
      }
      if (items.length >= 2) {
        groups.add(DuplicateGroup(contentHash: entry.key, files: items));
      }
    }
    // Sort by wasted space descending
    groups.sort((a, b) => b.wastedBytes.compareTo(a.wastedBytes));
    return groups;
  }
}

/// Top-level function required for compute() (must not be a closure or method).
Future<String> _hashFile(String path) async {
  final file = File(path);
  final stat = await file.stat();

  // For large files, hash first + last 4KB as a fast pre-check
  if (stat.size > kLargeFileSizeBytes) {
    final bytes = <int>[];
    final raf = await file.open();
    try {
      bytes.addAll(await raf.read(4096));
      await raf.setPosition(stat.size - 4096);
      bytes.addAll(await raf.read(4096));
    } finally {
      await raf.close();
    }
    return md5.convert(bytes).toString();
  }

  final input = file.openRead();
  final digest = await md5.bind(input).first;
  return digest.toString();
}
