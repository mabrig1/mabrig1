import 'dart:io';

enum JunkCategory {
  appCache('App Cache', 'Cached data from installed apps'),
  thumbnails('Thumbnails', 'Auto-generated image thumbnails'),
  tempFiles('Temp Files', 'Temporary and backup files'),
  logFiles('Log Files', 'Application log and crash files'),
  obsoleteApks('APK Files', 'Downloaded installer packages'),
  emptyDirectories('Empty Folders', 'Folders with no content');

  const JunkCategory(this.label, this.description);
  final String label;
  final String description;
}

class FileItem {
  final String path;
  final String name;
  final int sizeBytes;
  final DateTime lastModified;
  final JunkCategory? category;
  bool isSelected;

  FileItem({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.lastModified,
    this.category,
    this.isSelected = true,
  });

  static Future<FileItem> fromFile(File file, {JunkCategory? category}) async {
    final stat = await file.stat();
    return FileItem(
      path: file.path,
      name: file.uri.pathSegments.last,
      sizeBytes: stat.size,
      lastModified: stat.modified,
      category: category,
    );
  }

  static Future<FileItem> fromDirectory(
    Directory dir, {
    JunkCategory? category,
  }) async {
    final stat = await dir.stat();
    return FileItem(
      path: dir.path,
      name: dir.uri.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => dir.path),
      sizeBytes: 0,
      lastModified: stat.modified,
      category: category,
    );
  }

  FileItem copyWith({bool? isSelected}) {
    return FileItem(
      path: path,
      name: name,
      sizeBytes: sizeBytes,
      lastModified: lastModified,
      category: category,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
