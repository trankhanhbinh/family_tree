import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:familytree/features/tree/data/clan_info_provider.dart';

// Giá trị cột entity_type / action của bảng change_requests.
const String kEntityPerson = 'person';
const String kActionCreate = 'create';
const String kActionUpdate = 'update';
const String kActionDelete = 'delete';

class ChangeRequestRepository {
  ChangeRequestRepository(this._client);

  final SupabaseClient _client;

  /// Gửi một đề xuất. status do trigger của database ép thành 'pending'.
  /// Ném lỗi nếu thất bại (nơi gọi hiện bằng showErrorDialog).
  Future<void> submit({
    required String requesterId,
    required String nickname,
    required String entityType,
    String? entityId,
    required String action,
    required Map<String, dynamic> payload,
    String? note,
  }) async {
    await _client.from('change_requests').insert({
      'requester_id': requesterId,
      'nickname': nickname,
      'entity_type': entityType,
      'entity_id': ?entityId,
      'action': action,
      'payload': payload,
      'note': ?note,
    });
  }
}

final changeRequestRepositoryProvider = Provider<ChangeRequestRepository>((ref) {
  return ChangeRequestRepository(ref.watch(supabaseClientProvider));
});