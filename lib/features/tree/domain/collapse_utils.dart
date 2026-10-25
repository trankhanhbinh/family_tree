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