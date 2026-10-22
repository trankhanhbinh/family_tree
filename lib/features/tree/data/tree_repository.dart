import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/person/domain/person_photo.dart';
import 'package:familytree/features/tree/data/clan_info_provider.dart';
import 'package:familytree/features/tree/domain/branch.dart';
import 'package:familytree/features/tree/domain/marriage.dart';
import 'package:familytree/features/tree/domain/parent_child.dart';
import 'package:familytree/features/tree/domain/tree_data.dart';

class TreeRepository {
  TreeRepository(this._client);

  final SupabaseClient _client;

  Future<TreeData> fetchAll() async {
    // Tải song song 5 bảng
    final (people, branches, parentChildren, marriages, photos) = await (
      _fetchAllRows('people'),
      _fetchAllRows('branches'),
      _fetchAllRows('parent_child'),
      _fetchAllRows('marriages'),
      _fetchAllRows('person_photos'),
    ).wait;

    return TreeData(
      // Bỏ người đã xóa mềm (admin mới nhìn thấy họ)
      people: people
          .map(Person.fromJson)
          .where((p) => p.deletedAt == null)
          .toList(),
      branches: branches.map(Branch.fromJson).toList(),
      parentChildren: parentChildren.map(ParentChild.fromJson).toList(),
      marriages: marriages.map(Marriage.fromJson).toList(),
      photos: photos.map(PersonPhoto.fromJson).toList(),
    );
  }

  /// Supabase giới hạn 1000 dòng mỗi lần, nên tải theo từng trang.
  Future<List<Map<String, dynamic>>> _fetchAllRows(String table) async {
    const pageSize = 1000;
    final rows = <Map<String, dynamic>>[];
    var from = 0;

    while (true) {
      final page = await _client
          .from(table)
          .select()
          .order('id')
          .range(from, from + pageSize - 1);
      rows.addAll(page);
      if (page.length < pageSize) break;
      from += pageSize;
    }
    return rows;
  }
}

final treeRepositoryProvider = Provider<TreeRepository>((ref) {
  return TreeRepository(ref.watch(supabaseClientProvider));
});

final treeDataProvider = FutureProvider<TreeData>(
  retry: (retryCount, error) => null,
  (ref) async {
    return ref
        .watch(treeRepositoryProvider)
        .fetchAll()
        .timeout(const Duration(seconds: 20));
  },
);