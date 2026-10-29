import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:familytree/features/history/domain/history_entry.dart';
import 'package:familytree/features/history/domain/history_feed_state.dart';
import 'package:familytree/features/tree/data/clan_info_provider.dart';

class HistoryRepository {
  HistoryRepository(this._client);

  final SupabaseClient _client;

  /// Một trang lịch sử, mới nhất trước. Thứ tự phụ theo id để các dòng
  /// cùng created_at (cùng giao dịch) không bị lặp hoặc sót giữa hai trang.
  /// [personId] = null: toàn dòng họ. Người không phải admin sẽ nhận
  /// danh sách rỗng (RLS), không có lỗi.
  Future<List<HistoryEntry>> fetchPage({
    required int offset,
    String? personId,
  }) async {
    var query = _client.from('change_history').select();
    if (personId != null) {
      query = query.or(personHistoryFilter(personId));
    }
    final rows = await query
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .range(offset, offset + kHistoryPageSize - 1)
        .timeout(const Duration(seconds: 20));
    return rows.map(HistoryEntry.fromJson).toList();
  }
}

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepository(ref.watch(supabaseClientProvider));
});

/// Danh sách lịch sử tải dần. Tham số = id người (null = toàn dòng họ).
class HistoryFeed extends AsyncNotifier<HistoryFeedState> {
  HistoryFeed(this.personId);

  final String? personId;

  @override
  Future<HistoryFeedState> build() async {
    final repository = ref.watch(historyRepositoryProvider);
    final page = await repository.fetchPage(offset: 0, personId: personId);
    return HistoryFeedState.firstPage(page);
  }

  /// Tải trang kế tiếp. Lỗi thì giữ nguyên dữ liệu đã có và ghi vào loadError.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) {
      return;
    }
    final repository = ref.read(historyRepositoryProvider);
    state = AsyncData(current.startLoadingMore());
    try {
      final page = await repository.fetchPage(
        offset: current.fetchedCount,
        personId: personId,
      );
      if (!ref.mounted) {
        return;
      }
      state = AsyncData(current.appendPage(page));
    } catch (error) {
      if (!ref.mounted) {
        return;
      }
      state = AsyncData(current.failedLoadingMore(error));
    }
  }
}

final historyFeedProvider = AsyncNotifierProvider.autoDispose
    .family<HistoryFeed, HistoryFeedState, String?>(
  HistoryFeed.new,
  // Tắt tự động thử lại để nút "Thử lại" do mình điều khiển.
  retry: (retryCount, error) => null,
);