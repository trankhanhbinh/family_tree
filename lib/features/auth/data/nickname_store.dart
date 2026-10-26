import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:familytree/features/auth/domain/nickname_rules.dart';

/// Lưu nickname trên máy. Mọi lỗi đọc/ghi chỉ ghi log (không làm sập app):
/// nếu plugin hỏng (như sự cố điện thoại thật) thì app hỏi lại tên mỗi lần.
class NicknameStore {
  static const String _key = 'contributor_nickname';

  Future<String?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_key);
    } catch (error) {
      debugPrint('Không đọc được nickname: $error');
      return null;
    }
  }

  Future<void> write(String nickname) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, nickname);
    } catch (error) {
      debugPrint('Không lưu được nickname: $error');
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (error) {
      debugPrint('Không xóa được nickname: $error');
    }
  }
}

final nicknameStoreProvider = Provider<NicknameStore>((ref) {
  return NicknameStore();
});

class NicknameNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() {
    return ref.read(nicknameStoreProvider).read();
  }

  Future<void> save(String nickname) async {
    final clean = normalizeNickname(nickname);
    await ref.read(nicknameStoreProvider).write(clean);
    state = AsyncData(clean);
  }

  Future<void> clear() async {
    await ref.read(nicknameStoreProvider).clear();
    state = const AsyncData(null);
  }
}

final nicknameProvider =
    AsyncNotifierProvider<NicknameNotifier, String?>(NicknameNotifier.new);