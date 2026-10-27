class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  
  /// Email cố định của tài khoản admin (chỉ là email; mã là mật khẩu, nhập lúc đăng nhập).
  static const adminEmail = String.fromEnvironment('ADMIN_EMAIL');
  
  /// Báo lỗi rõ ràng nếu quên chạy với --dart-define-from-file=env.json
  static void assertConfigured() {
    if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
      throw StateError(
        'Thiếu SUPABASE_URL hoặc SUPABASE_PUBLISHABLE_KEY. '
        'Hãy chạy: flutter run --dart-define-from-file=env.json',
      );
    }
  }
}