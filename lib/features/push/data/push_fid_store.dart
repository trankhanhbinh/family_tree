import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Nhớ trên máy này: FID (để đăng xuất xóa đúng dòng trong admin_devices) và
/// cờ "admin đã tắt thông báo trên máy này".
/// Mọi lỗi đọc/ghi chỉ ghi log, không làm sập app.
class PushFidStore {
  static const String _fidKey = 'push_device_fid';
  static const String _optedOutKey = 'push_opted_out';
  static const String _pendingDeleteKey = 'push_pending_delete_fids';

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

  Future<List<String>> readPendingDeletes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_pendingDeleteKey) ?? const <String>[];
    } catch (error) {
      debugPrint('Không đọc được danh sách FID chờ xóa: $error');
      return const <String>[];
    }
  }

  Future<void> addPendingDelete(String fid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = List<String>.of(
        prefs.getStringList(_pendingDeleteKey) ?? const <String>[],
      );
      if (!list.contains(fid)) {
        list.add(fid);
        await prefs.setStringList(_pendingDeleteKey, list);
      }
    } catch (error) {
      debugPrint('Không ghi được FID chờ xóa: $error');
    }
  }

  Future<void> removePendingDelete(String fid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = List<String>.of(
        prefs.getStringList(_pendingDeleteKey) ?? const <String>[],
      );
      if (!list.remove(fid)) {
        return;
      }
      if (list.isEmpty) {
        await prefs.remove(_pendingDeleteKey);
      } else {
        await prefs.setStringList(_pendingDeleteKey, list);
      }
    } catch (error) {
      debugPrint('Không gỡ được FID chờ xóa: $error');
    }
  }
}

final pushFidStoreProvider = Provider<PushFidStore>((ref) {
  return PushFidStore();
});
