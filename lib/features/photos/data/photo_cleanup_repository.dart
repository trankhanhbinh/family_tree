import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:familytree/features/photos/data/pending_photo_service.dart';
import 'package:familytree/features/photos/data/photo_service.dart';
import 'package:familytree/features/photos/domain/orphan_files.dart';
import 'package:familytree/features/tree/data/clan_info_provider.dart';

class PhotoCleanupRepository {
  PhotoCleanupRepository(this._client);

  final SupabaseClient _client;

  /// Số file xóa mỗi lần gọi Storage.
  static const int batchSize = 50;

  Future<List<OrphanFile>> _list(String bucket) async {
    final rows = await _client
        .rpc('admin_list_orphan_photo_files', params: {'p_bucket': bucket})
        .timeout(const Duration(seconds: 30));
    return (rows as List)
        .map((row) => OrphanFile.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  /// Quét cả hai bucket. Chỉ admin gọi được (hàm SQL kiểm tra is_admin()).
  Future<OrphanScan> scan() async {
    final publicFiles = await _list(PhotoService.bucket);
    final pendingFiles = await _list(PendingPhotoService.bucket);
    return OrphanScan(publicFiles: publicFiles, pendingFiles: pendingFiles);
  }

  /// Xóa theo lô. Lô nào lỗi thì tính là chưa xóa được và đi tiếp lô khác.
  Future<CleanupResult> remove(OrphanScan scan) async {
    var deleted = 0;
    var failed = 0;

    final targets = <String, List<String>>{
      PhotoService.bucket: scan.publicFiles.map((f) => f.name).toList(),
      PendingPhotoService.bucket: scan.pendingFiles.map((f) => f.name).toList(),
    };

    for (final target in targets.entries) {
      for (final batch in chunkList(target.value, batchSize)) {
        final removed = await _removeBatch(target.key, batch);
        deleted += removed;
        failed += batch.length - removed;
      }
    }
    return CleanupResult(deleted: deleted, failed: failed);
  }

  Future<int> _removeBatch(String bucket, List<String> names) async {
    try {
      final removed = await _client.storage
          .from(bucket)
          .remove(names)
          .timeout(const Duration(seconds: 60));
      return removed.length;
    } catch (error) {
      debugPrint('Không xóa được một lô file ở $bucket: $error');
      return 0;
    }
  }
}

final photoCleanupRepositoryProvider = Provider<PhotoCleanupRepository>((ref) {
  return PhotoCleanupRepository(ref.watch(supabaseClientProvider));
});

final photoOrphanScanProvider = FutureProvider.autoDispose<OrphanScan>(
  (ref) => ref.watch(photoCleanupRepositoryProvider).scan(),
  retry: (retryCount, error) => null,
);