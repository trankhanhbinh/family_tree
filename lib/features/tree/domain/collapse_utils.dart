import 'package:familytree/features/tree/domain/family_node.dart';

/// Id các người chính có con ở hàng >= 1 (gốc luôn được giữ mở).
/// Dùng cho nút "Thu gọn tất cả".
Set<String> collapsibleNonRootIds(FamilyForest forest) {
  final result = <String>{};

  void visit(FamilyNode node, int row) {
    if (row >= 1 && node.hasChildren) {
      result.add(node.person.id);
    }
    for (final union in node.unions) {
      for (final child in union.children) {
        visit(child, row + 1);
      }
    }
  }

  for (final root in forest.roots) {
    visit(root, 0);
  }
  return result;
}

/// Với mỗi người: danh sách id các người chính (tổ tiên) phải ĐANG MỞ thì
/// thẻ của người đó mới hiện. Không gồm chính người đó.
/// Vợ/chồng ngoại họ: lấy theo tổ tiên của người chính đứng cạnh.
Map<String, List<String>> collapseBlockersOf(FamilyForest forest) {
  final result = <String, List<String>>{};

  void visit(FamilyNode node, List<String> path) {
    result[node.person.id] = path;
    for (final union in node.unions) {
      final spouse = union.spouse;
      if (spouse != null) {
        result.putIfAbsent(spouse.id, () => path);
      }
      for (final child in union.children) {
        visit(child, [...path, node.person.id]);
      }
    }
  }

  for (final root in forest.roots) {
    visit(root, const <String>[]);
  }
  return result;
}