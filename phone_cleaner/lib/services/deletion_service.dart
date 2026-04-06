import 'dart:io';
import '../data/models/file_item.dart';

class DeletionResult {
  final int deletedCount;
  final int freedBytes;
  final List<String> failedPaths;

  const DeletionResult({
    required this.deletedCount,
    required this.freedBytes,
    required this.failedPaths,
  });

  bool get hasErrors => failedPaths.isNotEmpty;
}

class DeletionService {
  Future<DeletionResult> deleteItems(List<FileItem> items) async {
    int deletedCount = 0;
    int freedBytes = 0;
    final List<String> failed = [];

    // Sort: deepest paths (longest) first to handle empty directories correctly
    final sorted = List<FileItem>.from(items)
      ..sort((a, b) => b.path.length.compareTo(a.path.length));

    for (final item in sorted) {
      try {
        final type = FileSystemEntity.typeSync(item.path);
        if (type == FileSystemEntityType.directory) {
          await Directory(item.path).delete(recursive: true);
        } else if (type == FileSystemEntityType.file) {
          await File(item.path).delete();
          freedBytes += item.sizeBytes;
        }
        deletedCount++;
      } catch (_) {
        failed.add(item.path);
      }
    }

    return DeletionResult(
      deletedCount: deletedCount,
      freedBytes: freedBytes,
      failedPaths: failed,
    );
  }
}
