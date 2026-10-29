import 'package:familytree/features/history/domain/history_entry.dart';

/// Trạng thái danh sách lịch sử đang tải dần từng trang.
class HistoryFeedState {
  const HistoryFeedState({
    required this.entries,
    required this.fetchedCount,
    required this.hasMore,
    this.loadingMore = false,
    this.loadError,
  });

  factory HistoryFeedState.firstPage(List<HistoryEntry> page) {
    return HistoryFeedState(
      entries: page,
      fetchedCount: page.length,
      hasMore: page.length >= kHistoryPageSize,
    );
  }

  final List<HistoryEntry> entries;

  /// Số dòng đã lấy từ server (dùng làm offset cho trang kế tiếp).
  final int fetchedCount;
  final bool hasMore;
  final bool loadingMore;
  final Object? loadError;

  /// Gom lại trên TOÀN BỘ dòng đã tải, nên nhóm bị cắt giữa hai trang
  /// tự được ghép lại.
  List<HistoryGroup> get groups => groupHistory(entries);

  HistoryFeedState startLoadingMore() {
    return HistoryFeedState(
      entries: entries,
      fetchedCount: fetchedCount,
      hasMore: hasMore,
      loadingMore: true,
    );
  }

  HistoryFeedState failedLoadingMore(Object error) {
    return HistoryFeedState(
      entries: entries,
      fetchedCount: fetchedCount,
      hasMore: hasMore,
      loadError: error,
    );
  }

  HistoryFeedState appendPage(List<HistoryEntry> page) {
    final known = {for (final entry in entries) entry.id};
    final merged = [
      ...entries,
      for (final entry in page)
        if (!known.contains(entry.id)) entry,
    ];
    return HistoryFeedState(
      entries: merged,
      fetchedCount: fetchedCount + page.length,
      hasMore: page.length >= kHistoryPageSize,
    );
  }
}