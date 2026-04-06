import 'file_item.dart';

class ScanResult {
  final List<FileItem> items;
  final DateTime scannedAt;
  final Duration scanDuration;

  ScanResult({
    required this.items,
    required this.scannedAt,
    required this.scanDuration,
  });

  int get totalSizeBytes => items.fold(0, (sum, f) => sum + f.sizeBytes);
  int get fileCount => items.length;

  Map<JunkCategory, List<FileItem>> get byCategory {
    final map = <JunkCategory, List<FileItem>>{};
    for (final item in items) {
      if (item.category != null) {
        map.putIfAbsent(item.category!, () => []).add(item);
      }
    }
    return map;
  }

  int sizeForCategory(JunkCategory category) {
    return (byCategory[category] ?? []).fold(0, (s, f) => s + f.sizeBytes);
  }

  bool get isEmpty => items.isEmpty;

  static ScanResult empty() => ScanResult(
        items: [],
        scannedAt: DateTime.now(),
        scanDuration: Duration.zero,
      );
}
