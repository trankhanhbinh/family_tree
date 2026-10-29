import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:familytree/features/history/domain/deleted_person.dart';
import 'package:familytree/features/history/domain/restore_result.dart';
import 'package:familytree/features/tree/data/clan_info_provider.dart';

class DeletedPeopleRepository {
  DeletedPeopleRepository(this._client);

  final SupabaseClient _client;

  /// Người đã xóa mềm, mới xóa nằm trên. Chỉ admin thấy (RLS của people);
  /// người thường nhận danh sách rỗng.
  Future<List<DeletedPerson>> fetchDeleted() async {
    final rows = await _client
        .from('people')
        .select('id, full_name, birth_year, death_year, deleted_at')
        .not('deleted_at', 'is', null)
        .order('deleted_at', ascending: false)
        .timeout(const Duration(seconds: 20));
    return rows.map(DeletedPerson.fromJson).toList();
  }

  /// Gọi hàm admin_restore_person: khôi phục người cùng các quan hệ
  /// bị gỡ trong lần xóa đó, trong MỘT giao dịch.
  Future<RestoreResult> restore(String personId) async {
    final result = await _client
        .rpc('admin_restore_person', params: {'p_person_id': personId})
        .timeout(const Duration(seconds: 30));
    return RestoreResult.fromJson(Map<String, dynamic>.from(result as Map));
  }
}

final deletedPeopleRepositoryProvider = Provider<DeletedPeopleRepository>((ref) {
  return DeletedPeopleRepository(ref.watch(supabaseClientProvider));
});

final deletedPeopleProvider =
    FutureProvider.autoDispose<List<DeletedPerson>>(
  (ref) => ref.watch(deletedPeopleRepositoryProvider).fetchDeleted(),
  retry: (retryCount, error) => null,
);