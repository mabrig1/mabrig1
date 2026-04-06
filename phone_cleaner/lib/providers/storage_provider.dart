import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/storage_info.dart';
import '../services/storage_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) => StorageService());

final storageInfoProvider = FutureProvider<StorageInfo>((ref) async {
  return ref.watch(storageServiceProvider).getStorageInfo();
});
