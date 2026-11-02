import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Nhớ trên máy này: người dùng đã bật nhắc ngày giỗ chưa (mặc định: chưa).
/// Mọi lỗi đọc/ghi chỉ ghi log, không làm sập app.
class MemorialReminderStore {
  static const String _enabledKey = 'memorial_reminders_enabled';

  Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_enabledKey) ?? false;
    } catch (error) {
      debugPrint('Không đọc được cờ nhắc ngày giỗ: $error');
      return false;
    }
  }

  Future<void> setEnabled(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, value);
    } catch (error) {
      debugPrint('Không lưu được cờ nhắc ngày giỗ: $error');
    }
  }
}

final memorialReminderStoreProvider = Provider<MemorialReminderStore>((ref) {
  return MemorialReminderStore();
});