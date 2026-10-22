class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

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