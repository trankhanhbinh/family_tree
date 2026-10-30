import 'package:familytree/features/branch/domain/branch_usage.dart';
import 'package:familytree/features/tree/domain/branch.dart';

/// Một dòng trong danh sách chi thụt lề.
class BranchRow {
  const BranchRow({
    required this.branch,
    required this.depth,
    required this.livingCount,
    required this.hasChildren,
  });

  final Branch branch;
  final int depth;

  /// Số người đang sống thuộc TRỰC TIẾP chi này (không cộng chi con).
  final int livingCount;
  final bool hasChildren;
}

/// Thứ tự anh em: sort_order, rồi tên (không phân biệt hoa thường), rồi id.
int compareBranches(Branch a, Branch b) {
  final bySort = a.sortOrder.compareTo(b.sortOrder);
  if (bySort != 0) {
    return bySort;
  }
  final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
  return byName != 0 ? byName : a.id.compareTo(b.id);
}

/// Danh sách chi phẳng, đã sắp theo cây (cha trước con), có độ thụt lề.
/// - Chi có cha không còn trong danh sách (hoặc bị loại bởi excludeIds) được coi là chi gốc.
/// - Dữ liệu bị vòng (không với tới từ chi gốc nào) thì không hiện, không treo.
List<BranchRow> buildBranchRows({
  required Iterable<Branch> branches,
  required BranchUsage usage,
  Set<String> excludeIds = const {},
}) {
  final visible = branches.where((b) => !excludeIds.contains(b.id)).toList();
  final visibleIds = {for (final b in visible) b.id};

  final childrenOf = <String?, List<Branch>>{};
  for (final branch in visible) {
    final parentId = branch.parentBranchId;
    final key = (parentId != null && visibleIds.contains(parentId))
        ? parentId
        : null;
    childrenOf.putIfAbsent(key, () => <Branch>[]).add(branch);
  }
  for (final list in childrenOf.values) {
    list.sort(compareBranches);
  }

  final rows = <BranchRow>[];
  final visited = <String>{};

  void walk(String? parentKey, int depth) {
    for (final branch in childrenOf[parentKey] ?? const <Branch>[]) {
      if (!visited.add(branch.id)) {
        continue;
      }
      final kids = childrenOf[branch.id];
      rows.add(
        BranchRow(
          branch: branch,
          depth: depth,
          livingCount: usage.livingCount(branch.id),
          hasChildren: kids != null && kids.isNotEmpty,
        ),
      );
      walk(branch.id, depth + 1);
    }
  }

  walk(null, 0);
  return rows;
}