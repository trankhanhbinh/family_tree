import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:familytree/features/tree/data/clan_info_provider.dart';

/// Làm việc với bucket công khai person-photos.
class PhotoService {
  PhotoService(this._client);

  final SupabaseClient _client;

  static const String bucket = 'person-photos';

  /// Đường dẫn công khai để xem ảnh (không cần đăng nhập).
  String publicUrl(String storagePath) {
    return _client.storage.from(bucket).getPublicUrl(storagePath);
  }

  /// Tải ảnh lên (chỉ admin ghi được). Ghi đè nếu đã có (an toàn khi thử lại).
  Future<void> upload({
    required String storagePath,
    required Uint8List bytes,
    required String contentType,
  }) async {
    await _client.storage
        .from(bucket)
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        )
        .timeout(const Duration(seconds: 60));
  }

  /// Xóa file vừa tải lên khi bước tạo dòng ảnh thất bại. Không bao giờ ném lỗi.
  Future<void> removeQuietly(String storagePath) async {
    try {
      await _client.storage.from(bucket).remove([storagePath]);
    } catch (error) {
      debugPrint('Không xóa được file ảnh vừa tải lên: $error');
    }
  }
}

final photoServiceProvider = Provider<PhotoService>((ref) {
  return PhotoService(ref.watch(supabaseClientProvider));
});
