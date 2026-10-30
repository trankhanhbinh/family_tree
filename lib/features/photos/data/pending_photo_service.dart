import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:familytree/features/tree/data/clan_info_provider.dart';

/// Làm việc với bucket RIÊNG pending-photos (ảnh chờ duyệt).
/// Người đóng góp: tải lên / xóa file của chính mình. Admin: đọc và xóa mọi file.
class PendingPhotoService {
  PendingPhotoService(this._client);

  final SupabaseClient _client;

  static const String bucket = 'pending-photos';

  /// Số file chờ hiện có của người dùng (thư mục {uid}/).
  Future<int> countOwn(String userId) async {
    final files = await _client.storage
        .from(bucket)
        .list(path: userId)
        .timeout(const Duration(seconds: 20));
    return files.length;
  }

  /// Tải lên {uid}/{photo_id}.{đuôi}.
  Future<void> upload({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    try {
      await _client.storage
          .from(bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType),
          )
          .timeout(const Duration(seconds: 60));
    } on StorageException catch (error) {
      // 409: file này đã được tải lên ở lần thử trước (cùng id) -> coi như xong.
      if (error.statusCode == '409') {
        return;
      }
      rethrow;
    }
  }

  /// Admin: tải nội dung file chờ về.
  Future<Uint8List> download(String path) {
    return _client.storage
        .from(bucket)
        .download(path)
        .timeout(const Duration(seconds: 60));
  }

  /// Đường dẫn tạm (1 giờ) để xem file chờ. Admin và chủ file xem được.
  Future<String> signedUrl(String path) {
    return _client.storage.from(bucket).createSignedUrl(path, 3600);
  }

  /// Xóa file chờ. Không bao giờ ném lỗi.
  Future<void> removeQuietly(String path) async {
    try {
      await _client.storage.from(bucket).remove([path]);
    } catch (error) {
      debugPrint('Không xóa được file chờ $path: $error');
    }
  }
}

final pendingPhotoServiceProvider = Provider<PendingPhotoService>((ref) {
  return PendingPhotoService(ref.watch(supabaseClientProvider));
});