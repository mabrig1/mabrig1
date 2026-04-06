import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<int> getAndroidSdkVersion() async {
    if (!Platform.isAndroid) return 0;
    final info = await DeviceInfoPlugin().androidInfo;
    return info.version.sdkInt;
  }

  /// Request all necessary storage permissions based on Android SDK version.
  /// Returns true if access is sufficient to scan/delete files.
  static Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return false;

    final sdkInt = await getAndroidSdkVersion();

    if (sdkInt >= 30) {
      // Android 11+: Need MANAGE_EXTERNAL_STORAGE for full access.
      // This can only be granted via Settings intent.
      if (await Permission.manageExternalStorage.isGranted) return true;
      final status = await Permission.manageExternalStorage.request();
      if (status.isPermanentlyDenied || status.isDenied) {
        await openAppSettings();
      }
      return status.isGranted;
    } else if (sdkInt >= 33) {
      // Android 13+: Granular media permissions
      final results = await [
        Permission.photos,
        Permission.videos,
        Permission.audio,
      ].request();
      return results.values.every((s) => s.isGranted);
    } else {
      // Android 6-10
      final status = await Permission.storage.request();
      if (status.isPermanentlyDenied) {
        await openAppSettings();
      }
      return status.isGranted;
    }
  }

  static Future<bool> hasStoragePermission() async {
    if (!Platform.isAndroid) return false;
    final sdkInt = await getAndroidSdkVersion();
    if (sdkInt >= 30) {
      return Permission.manageExternalStorage.isGranted;
    }
    return Permission.storage.isGranted;
  }
}
