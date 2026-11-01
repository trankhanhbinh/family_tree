import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Nhớ trên máy này: FID (để đăng xuất xóa đúng dòng trong admin_devices) và
/// cờ "admin đã tắt thông báo trên máy này".
/// Mọi lỗi đọc/ghi chỉ ghi log, không làm sập app.
class PushFidStore {
  static const String _fidKey = 'push_device_fid';
  static const String _optedOutKey = 'push_opted_out';

  Future<String?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_fidKey);
    } catch (error) {
      debugPrint('Không đọc được FID đã nhớ: $error');
      return null;
    }
  }

  Future<void> write(String fid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_fidKey, fid);
    } catch (error) {
      debugPrint('Không lưu được FID: $error');
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_fidKey);
    } catch (error) {
      debugPrint('Không xóa được FID đã nhớ: $error');
    }
  }

  /// Admin đã tắt thông báo trên máy này chưa. Lỗi đọc thì coi như chưa tắt.
  Future<bool> isOptedOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_optedOutKey) ?? false;
    } catch (error) {
      debugPrint('Không đọc được cờ tắt thông báo: $error');
      return false;
    }
  }

  Future<void> setOptedOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_optedOutKey, true);
    } catch (error) {
      debugPrint('Không lưu được cờ tắt thông báo: $error');
    }
  }

  Future<void> clearOptedOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_optedOutKey);
    } catch (error) {
      debugPrint('Không xóa được cờ tắt thông báo: $error');
    }
  }
}

final pushFidStoreProvider = Provider<PushFidStore>((ref) {
  return PushFidStore();
});