import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../core/constants/junk_paths.dart';
import '../core/utils/file_utils.dart';
import '../data/models/file_item.dart';
import '../data/models/scan_result.dart';

class ScanProgress {
  final String currentPath;
  final int filesFound;
  final int bytesFound;

  const ScanProgress({
    required this.currentPath,
    required this.filesFound,
    required this.bytesFound,
  });
}

class FileScannerService {
  bool _cancelled = false;
  final List<FileItem> _items = [];

  void cancel() => _cancelled = true;

  Stream<ScanProgress> scanForJunk(List<Directory> roots) async* {
    _cancelled = false;
    _items.clear();
    int filesFound = 0;
    int bytesFound = 0;

    for (final root in roots) {
      if (_cancelled) return;

      // 1. Scan glob-matched junk directories
      for (final pattern in kJunkDirectoryPatterns) {
        if (_cancelled) return;
        final dirs = await FileUtils.resolveGlobPattern(root, pattern);
        for (final dir in dirs) {
          if (_cancelled) return;
          try {
            await for (final entity
                in dir.list(recursive: true, followLinks: false)) {
              if (_cancelled) return;
              if (entity is File) {
                try {
                  final stat = await entity.stat();
                  final category = _categoryForPattern(pattern);
                  _items.add(FileItem(
                    path: entity.path,
                    name: entity.uri.pathSegments.last,
                    sizeBytes: stat.size,
                    lastModified: stat.modified,
                    category: category,
                  ));
                  filesFound++;
                  bytesFound += stat.size;
                  yield ScanProgress(
                    currentPath: entity.path,
                    filesFound: filesFound,
                    bytesFound: bytesFound,
                  );
                } catch (_) {}
              }
            }
          } catch (_) {}
        }
      }

      // 2. Walk entire storage for extension-based matches + empty dirs
      try {
        await for (final entity
            in root.list(recursive: true, followLinks: false)) {
          if (_cancelled) return;

          if (entity is File) {
            final ext = FileUtils.extension(entity.path);
            JunkCategory? category;

            if (kTempExtensions.contains(ext)) {
              category = JunkCategory.tempFiles;
            } else if (kLogExtensions.contains(ext)) {
              category = JunkCategory.logFiles;
            } else if (kApkExtension.contains(ext) &&
                entity.path.contains('Download')) {
              category = JunkCategory.obsoleteApks;
            }

            if (category != null) {
              // Skip if already picked up via glob scan
              if (!_items.any((i) => i.path == entity.path)) {
                try {
                  final stat = await entity.stat();
                  _items.add(FileItem(
                    path: entity.path,
                    name: entity.uri.pathSegments.last,
                    sizeBytes: stat.size,
                    lastModified: stat.modified,
                    category: category,
                  ));
                  filesFound++;
                  bytesFound += stat.size;
                  yield ScanProgress(
                    currentPath: entity.path,
                    filesFound: filesFound,
                    bytesFound: bytesFound,
                  );
                } catch (_) {}
              }
            }
          } else if (entity is Directory) {
            // Check for empty directory
            try {
              final contents = await entity.list().toList();
              if (contents.isEmpty) {
                _items.add(FileItem(
                  path: entity.path,
                  name: p.basename(entity.path),
                  sizeBytes: 0,
                  lastModified: (await entity.stat()).modified,
                  category: JunkCategory.emptyDirectories,
                ));
                filesFound++;
                yield ScanProgress(
                  currentPath: entity.path,
                  filesFound: filesFound,
                  bytesFound: bytesFound,
                );
              }
            } catch (_) {}
          }
        }
      } catch (_) {}
    }
  }

  ScanResult buildResult(Duration duration) {
    return ScanResult(
      items: List.from(_items),
      scannedAt: DateTime.now(),
      scanDuration: duration,
    );
  }

  JunkCategory _categoryForPattern(String pattern) {
    if (pattern.contains('cache') || pattern.contains('code_cache')) {
      return JunkCategory.appCache;
    }
    if (pattern.contains('thumbnail')) return JunkCategory.thumbnails;
    return JunkCategory.tempFiles;
  }
}
