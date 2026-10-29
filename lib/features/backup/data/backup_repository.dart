import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:familytree/features/backup/domain/backup_builder.dart';
import 'package:familytree/features/tree/data/clan_info_provider.dart';

class BackupRepository {
  BackupRepository(this._client);

  final SupabaseClient _client;

  /// Tải TOÀN BỘ một bảng, từng trang kBackupPageSize dòng, sắp theo id để
  /// các trang không trùng và không sót.
  Future<List<Map<String, dynamic>>> _fetchTable(String table) async {
    final all = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final page = await _client
          .from(table)
          .select()
          .order('id')
          .range(offset, offset + kBackupPageSize - 1)
          .timeout(const Duration(seconds: 30));
      all.addAll(page);
      if (page.length < kBackupPageSize) {
        break;
      }
      offset += kBackupPageSize;
    }
    return all;
  }

  /// Tải mới từ server toàn bộ các bảng cần sao lưu (nguyên dòng, mọi cột).
  /// Ai cũng gọi được; dòng nào bị RLS ẩn thì không có trong kết quả.
  Future<BackupData> fetchAll() async {
    final clanInfo = await _client
        .from('clan_info')
        .select()
        .eq('id', 1)
        .maybeSingle()
        .timeout(const Duration(seconds: 30));
    final branches = await _fetchTable('branches');
    final people = await _fetchTable('people');
    final parentChild = await _fetchTable('parent_child');
    final marriages = await _fetchTable('marriages');
    final personPhotos = await _fetchTable('person_photos');

    return BackupData(
      clanInfo: clanInfo,
      branches: branches,
      people: people,
      parentChild: parentChild,
      marriages: marriages,
      personPhotos: personPhotos,
    );
  }
}

final backupRepositoryProvider = Provider<BackupRepository>((ref) {
  return BackupRepository(ref.watch(supabaseClientProvider));
});