import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/features/clan/domain/clan_info.dart';
import 'package:familytree/features/tree/data/clan_info_provider.dart';

/// Đọc đủ 3 cột của clan_info để điền sẵn vào form sửa.
final clanInfoProvider = FutureProvider.autoDispose<ClanInfo>(
  retry: (retryCount, error) => null,
  (ref) async {
    final client = ref.watch(supabaseClientProvider);
    final row = await client
        .from('clan_info')
        .select('name, origin, description')
        .eq('id', 1)
        .single()
        .timeout(const Duration(seconds: 15));
    return ClanInfo.fromJson(row);
  },
);