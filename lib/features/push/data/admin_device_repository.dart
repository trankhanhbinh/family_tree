import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:familytree/features/push/domain/admin_device_row.dart';
import 'package:familytree/features/tree/data/clan_info_provider.dart';

/// Lưu và xóa thiết bị admin trong bảng admin_devices.
/// RLS chỉ cho admin ghi dòng của chính mình, nên xóa phải chạy TRƯỚC khi
/// đăng xuất. Ném lỗi nếu thất bại; nơi gọi tự quyết định có bỏ qua hay không.
class AdminDeviceRepository {
  AdminDeviceRepository(this._client);

  final SupabaseClient _client;

  /// Thêm mới hoặc cập nhật theo fcm_token (cập nhật last_seen_at).
  Future<void> saveDevice(
    String fid, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final row = buildAdminDeviceRow(fid: fid, now: DateTime.now());
    await _client
        .from('admin_devices')
        .upsert(row, onConflict: 'fcm_token')
        .timeout(timeout);
  }

  /// Xóa dòng của máy này theo FID. FID rỗng thì không làm gì.
  Future<void> deleteDevice(
    String fid, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final cleanFid = fid.trim();
    if (cleanFid.isEmpty) {
      return;
    }
    await _client
        .from('admin_devices')
        .delete()
        .eq('fcm_token', cleanFid)
        .timeout(timeout);
  }
}

final adminDeviceRepositoryProvider = Provider<AdminDeviceRepository>((ref) {
  return AdminDeviceRepository(ref.watch(supabaseClientProvider));
});
