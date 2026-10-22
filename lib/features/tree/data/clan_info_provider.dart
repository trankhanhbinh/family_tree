import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Khối B: chỉ lấy tên dòng họ để kiểm tra kết nối.
/// Khối C sẽ thay bằng model + repository đầy đủ.
final clanNameProvider = FutureProvider<String>(
  // Tắt tự động thử lại để nút "Thử lại" do mình điều khiển (xem ghi chú bên dưới)
  retry: (retryCount, error) => null,
  (ref) async {
    final client = ref.watch(supabaseClientProvider);
    final row = await client
        .from('clan_info')
        .select('name')
        .eq('id', 1)
        .single()
        .timeout(const Duration(seconds: 15));
    return row['name'] as String;
  },
);