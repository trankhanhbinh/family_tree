import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:familytree/features/proposals/domain/request_draft.dart';
import 'package:familytree/features/tree/data/clan_info_provider.dart';

class ChangeRequestRepository {
  ChangeRequestRepository(this._client);

  final SupabaseClient _client;

  /// Gửi một hoặc nhiều đề xuất bằng MỘT lệnh insert: hoặc tất cả thành công,
  /// hoặc tất cả bị hoàn tác (không có "người mồ côi").
  /// status do trigger của database ép thành 'pending'.
  /// Ghi chú gửi admin chỉ gắn vào dòng đầu tiên.
  /// Ném lỗi nếu thất bại (nơi gọi hiện bằng showErrorDialog).
  Future<void> submitAll({
    required String requesterId,
    required String nickname,
    required List<RequestDraft> drafts,
    String? note,
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
          'note': ?(i == 0 ? note : null),
        },
    ];
    await _client.from('change_requests').insert(rows);
  }
}

final changeRequestRepositoryProvider = Provider<ChangeRequestRepository>((ref) {
  return ChangeRequestRepository(ref.watch(supabaseClientProvider));
});