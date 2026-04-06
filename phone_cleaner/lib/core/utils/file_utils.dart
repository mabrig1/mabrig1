import 'dart:io';
import 'package:path/path.dart' as p;

class FileUtils {
  FileUtils._();

  /// Resolve a glob pattern like 'Android/data/*/cache' under [root].
  /// Only single-level '*' wildcards are supported.
  static Future<List<Directory>> resolveGlobPattern(
    Directory root,
    String pattern,
  ) async {
    final segments = pattern.split('/');
    return _resolveSegments(root, segments, 0);
  }

  static Future<List<Directory>> _resolveSegments(
    Directory current,
    List<String> segments,
    int index,
  ) async {
    if (index >= segments.length) return [current];

    final segment = segments[index];
    final results = <Directory>[];

    if (segment == '*') {
      try {
        await for (final entity in current.list(followLinks: false)) {
          if (entity is Directory) {
            final sub = await _resolveSegments(entity, segments, index + 1);
            results.addAll(sub);
          }
        }
      } catch (_) {}
    } else {
      final candidate = Directory(p.join(current.path, segment));
      if (await candidate.exists()) {
        final sub = await _resolveSegments(candidate, segments, index + 1);
        results.addAll(sub);
      }
    }

    return results;
  }

  /// Shorten a file path for display (show last 2 segments).
  static String shortenPath(String fullPath) {
    final parts = fullPath.split(Platform.pathSeparator);
    if (parts.length <= 2) return fullPath;
    return '.../${parts[parts.length - 2]}/${parts.last}';
  }

  /// Get the file extension in lowercase.
  static String extension(String path) {
    return p.extension(path).toLowerCase();
  }
}
