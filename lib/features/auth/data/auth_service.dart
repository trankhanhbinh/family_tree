import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:familytree/features/tree/data/clan_info_provider.dart';

class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  // Nếu splash và nút "Đề xuất" cùng gọi một lúc thì chỉ đăng nhập MỘT lần.
  Future<void>? _pending;

  User? get currentUser => _client.auth.currentUser;

  bool get isSignedIn => _client.auth.currentSession != null;

  /// Đảm bảo có phiên đăng nhập (đã có thì không làm gì).
  /// Ném lỗi nếu thất bại; nơi gọi hiện bằng showErrorDialog.
  Future<void> ensureSignedIn() {
    if (isSignedIn) {
      return Future<void>.value();
    }
    return _pending ??= _signInAnonymously().whenComplete(() {
      _pending = null;
    });
  }

  Future<void> _signInAnonymously() async {
    await _client.auth.signInAnonymously();
  }

  /// Dùng ở màn hình chờ: không bao giờ ném lỗi, chỉ ghi log.
  Future<bool> trySignInQuietly() async {
    try {
      await ensureSignedIn();
      return true;
    } catch (error) {
      debugPrint('Đăng nhập ẩn danh thất bại (vẫn cho xem cây): $error');
      return false;
    }
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(supabaseClientProvider));
});