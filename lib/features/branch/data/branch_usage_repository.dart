import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/features/branch/domain/branch_usage.dart';
import 'package:familytree/features/tree/data/clan_info_provider.dart';

/// Chỉ admin dùng: mọi người có gắn chi, kể cả người đã xóa mềm
/// (RLS chỉ cho admin thấy người đã xóa). Tải theo trang 1000 dòng.
final branchUsageProvider = FutureProvider.autoDispose<BranchUsage>(
  retry: (retryCount, error) => null,
  (ref) async {
    final client = ref.watch(supabaseClientProvider);
    const pageSize = 1000;
    final members = <BranchMember>[];
    var from = 0;

    while (true) {
      final page = await client
          .from('people')
          .select('id, full_name, branch_id, deleted_at')
          .not('branch_id', 'is', null)
          .order('id')
          .range(from, from + pageSize - 1)
          .timeout(const Duration(seconds: 20));
      members.addAll(page.map(BranchMember.fromJson));
      if (page.length < pageSize) {
        break;
      }
      from += pageSize;
    }
    return BranchUsage.fromMembers(members);
  },
);