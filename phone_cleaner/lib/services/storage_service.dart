import 'dart:io';
import 'package:disk_space_plus/disk_space_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../data/models/storage_info.dart';

class StorageService {
  Future<StorageInfo> getStorageInfo() async {
    try {
      final freeMb = await DiskSpacePlus.getFreeDiskSpace ?? 0;
      final totalMb = await DiskSpacePlus.getTotalDiskSpace ?? 0;
      return StorageInfo(
        totalBytes: (totalMb * 1024 * 1024).round(),
        freeBytes: (freeMb * 1024 * 1024).round(),
      );
    } catch (_) {
      return StorageInfo.empty;
    }
  }

  Future<List<Directory>> getStorageRoots() async {
    final roots = <Directory>[];
    try {
      // Internal storage: navigate from app-specific path to /storage/emulated/0
      final appDir = await getExternalStorageDirectory();
      if (appDir != null) {
        final internalRoot = _findStorageRoot(appDir.path);
        if (internalRoot != null && await Directory(internalRoot).exists()) {
          roots.add(Directory(internalRoot));
        }
      }

      // Try explicit path as fallback
      final emulated = Directory('/storage/emulated/0');
      if (await emulated.exists() && !roots.any((d) => d.path == emulated.path)) {
        roots.add(emulated);
      }

      // External SD cards
      final externalDirs = await getExternalStorageDirectories();
      if (externalDirs != null) {
        for (final dir in externalDirs) {
          final sdRoot = _findStorageRoot(dir.path);
          if (sdRoot != null &&
              !roots.any((d) => d.path == sdRoot) &&
              !sdRoot.contains('emulated')) {
            final sdDir = Directory(sdRoot);
            if (await sdDir.exists()) roots.add(sdDir);
          }
        }
      }
    } catch (_) {}

    return roots.isEmpty ? [Directory('/storage/emulated/0')] : roots;
  }

  /// Walk up from an app-specific path to find the storage root.
  /// e.g., /storage/emulated/0/Android/data/com.app/files -> /storage/emulated/0
  String? _findStorageRoot(String path) {
    final parts = path.split('/');
    // Look for pattern like /storage/emulated/0 or /storage/XXXX-XXXX
    for (int i = 0; i < parts.length; i++) {
      if (parts[i] == 'emulated' && i + 1 < parts.length) {
        return parts.sublist(0, i + 2).join('/');
      }
    }
    // External SD: /storage/XXXX-XXXX
    if (parts.length >= 3 && parts[1] == 'storage' && parts[2] != 'emulated') {
      return '/${parts[1]}/${parts[2]}';
    }
    return null;
  }
}
