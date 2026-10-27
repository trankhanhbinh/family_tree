import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:familytree/features/auth/data/admin_provider.dart';
import 'package:familytree/features/review/domain/change_request.dart';
import 'package:familytree/features/tree/data/clan_info_provider.dart';

class ReviewRepository {
  ReviewRepository(this._client);

  final SupabaseClient _client;

  /// Mọi dòng đang chờ duyệt (admin thấy tất cả nhờ RLS).
  Future<List<ChangeRequest>> fetchPending() async {
    final rows = await _client
        .from('change_requests')
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: true)
        .timeout(const Duration(seconds: 20));
    return rows.map(ChangeRequest.fromJson).toList();
  }

  /// Các dòng đã xử lý gần đây (mới nhất trước).
  Future<List<ChangeRequest>> fetchRecent() async {
    final rows = await _client
        .from('change_requests')
        .select()
        .neq('status', 'pending')
        .order('created_at', ascending: false)
        .limit(300)
        .timeout(const Duration(seconds: 20));
    return rows.map(ChangeRequest.fromJson).toList();
  }

  /// Duyệt cả gói trong MỘT giao dịch (tất cả hoặc không có gì).
  Future<void> approveBundle(List<String> requestIds) async {
    await _client
        .rpc('approve_change_bundle', params: {'p_request_ids': requestIds})
        .timeout(const Duration(seconds: 30));
  }

  /// Từ chối cả gói, bắt buộc có lý do.
  Future<void> rejectBundle(List<String> requestIds, String reason) async {
    await _client
        .rpc(
          'reject_change_bundle',
          params: {'p_request_ids': requestIds, 'p_reason': reason},
        )
        .timeout(const Duration(seconds: 30));
  }
}

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository(ref.watch(supabaseClientProvider));
});

/// Các gói đang chờ duyệt (cũ nhất trước). Người không phải admin: danh sách rỗng
/// và KHÔNG gọi mạng.
final pendingBundlesProvider = FutureProvider<List<ReviewBundle>>(
  retry: (retryCount, error) => null,
  (ref) async {
    if (!ref.watch(isAdminProvider)) {
      return const <ReviewBundle>[];
    }
    final requests = await ref.watch(reviewRepositoryProvider).fetchPending();
    return groupRequests(requests);
  },
);

/// 30 gói đã xử lý gần nhất (mới nhất trước).
final processedBundlesProvider = FutureProvider<List<ReviewBundle>>(
  retry: (retryCount, error) => null,
  (ref) async {
    if (!ref.watch(isAdminProvider)) {
      return const <ReviewBundle>[];
    }
    final requests = await ref.watch(reviewRepositoryProvider).fetchRecent();
    return groupRequests(requests, oldestFirst: false).take(30).toList();
  },
);

/// Số gói chờ duyệt để hiện trên thanh admin. null = chưa biết / không phải admin.
final pendingCountProvider = Provider<int?>((ref) {
  if (!ref.watch(isAdminProvider)) {
    return null;
  }
  return ref.watch(pendingBundlesProvider).value?.length;
});