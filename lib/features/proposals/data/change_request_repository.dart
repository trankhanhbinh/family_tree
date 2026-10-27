import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:familytree/features/proposals/domain/request_draft.dart';
import 'package:familytree/features/tree/data/clan_info_provider.dart';

/// Đổi danh sách RequestDraft thành tham số cho rpc admin_apply_changes.
/// Giữ nguyên thứ tự; entity_id chỉ có mặt khi bản nháp có entityId.
List<Map<String, dynamic>> buildAdminApplyParams(List<RequestDraft> drafts) {
  return [
    for (final d in drafts)
      {
        'entity_type': d.entityType,
        'action': d.action,
        'entity_id': ?d.entityId,
        'payload': d.payload,
      },
  ];
}

class ChangeRequestRepository {
  ChangeRequestRepository(this._client);

  final SupabaseClient _client;

  /// Gửi một hoặc nhiều đề xuất bằng MỘT lệnh insert: hoặc tất cả thành công,
  /// hoặc tất cả bị hoàn tác (không có "người mồ côi").
  /// status do trigger của database ép thành 'pending'.
  /// Ghi chú gửi admin chỉ gắn vào dòng thứ [noteIndex] (mặc định dòng đầu).
  /// Ném lỗi nếu thất bại (nơi gọi hiện bằng showErrorDialog).
  Future<void> submitAll({
    required String requesterId,
    required String nickname,
    required List<RequestDraft> drafts,
    String? note,
    int noteIndex = 0,
  }) async {
    if (drafts.isEmpty) {
      return;
    }
    final rows = <Map<String, dynamic>>[
      for (var i = 0; i < drafts.length; i++)
        {
          'requester_id': requesterId,
          'nickname': nickname,
          'entity_type': drafts[i].entityType,
          'entity_id': ?drafts[i].entityId,
          'action': drafts[i].action,
          'payload': drafts[i].payload,
          'note': ?(i == noteIndex ? note : null),
        },
    ];
    await _client.from('change_requests').insert(rows);
  }

  /// Admin lưu trực tiếp: database áp dụng lần lượt các bản nháp trong MỘT
  /// giao dịch (hàm admin_apply_changes), lịch sử ghi tên "Admin".
  /// Ném lỗi nếu thất bại (nơi gọi hiện bằng showErrorDialog).
  Future<void> applyAsAdmin(List<RequestDraft> drafts) async {
    if (drafts.isEmpty) {
      return;
    }
    await _client
        .rpc(
          'admin_apply_changes',
          params: {'p_drafts': buildAdminApplyParams(drafts)},
        )
        .timeout(const Duration(seconds: 30));
  }
}

final changeRequestRepositoryProvider = Provider<ChangeRequestRepository>((ref) {
  return ChangeRequestRepository(ref.watch(supabaseClientProvider));
});