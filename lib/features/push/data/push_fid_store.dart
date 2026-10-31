import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Nhớ FID của máy này (để đăng xuất xóa đúng dòng trong admin_devices).
/// Mọi lỗi đọc/ghi chỉ ghi log, không làm sập app.
class PushFidStore {
  static const String _key = 'push_device_fid';

  Future<String?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_key);
    } catch (error) {
      debugPrint('Không đọc được FID đã nhớ: $error');
      return null;
    }
  }

  Future<void> write(String fid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, fid);
    } catch (error) {
      debugPrint('Không lưu được FID: $error');
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (error) {
      debugPrint('Không xóa được FID đã nhớ: $error');
    }
  }
}

final pushFidStoreProvider = Provider<PushFidStore>((ref) {
  return PushFidStore();
});