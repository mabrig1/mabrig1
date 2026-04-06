class StorageInfo {
  final int totalBytes;
  final int freeBytes;

  const StorageInfo({
    required this.totalBytes,
    required this.freeBytes,
  });

  int get usedBytes => totalBytes - freeBytes;
  double get usedPercent => totalBytes > 0 ? usedBytes / totalBytes : 0;
  double get freePercent => totalBytes > 0 ? freeBytes / totalBytes : 0;

  static const StorageInfo empty = StorageInfo(totalBytes: 0, freeBytes: 0);
}
