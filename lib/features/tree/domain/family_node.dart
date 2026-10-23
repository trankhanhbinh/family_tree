import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/tree/domain/marriage.dart';

/// Một "đơn vị gia đình" của người chính: một người bạn đời (có thể null
/// nếu con chỉ có một cha/mẹ trong dữ liệu) cùng các con của cặp đó.
class UnionGroup {
  UnionGroup({this.spouse, this.marriage});

  final Person? spouse;
  final Marriage? marriage;
  final List<FamilyNode> children = [];
}

/// Một người "trong họ" được đặt trên cây, kèm các đơn vị gia đình của họ
/// theo thứ tự hôn nhân.
class FamilyNode {
  FamilyNode(this.person);

  final Person person;
  final List<UnionGroup> unions = [];

  bool get hasChildren => unions.any((u) => u.children.isNotEmpty);
}

/// Kết quả gom dữ liệu: toàn bộ rừng cây (thường chỉ có 1 gốc).
class FamilyForest {
  const FamilyForest({
    required this.roots,
    required this.nodeOfPerson,
    required this.spouseOnlyIds,
    required this.warnings,
  });

  final List<FamilyNode> roots;

  /// id người -> nút chứa người đó (người chính: nút của chính họ;
  /// vợ/chồng ngoại họ: nút của người chính đầu tiên có họ).
  final Map<String, FamilyNode> nodeOfPerson;

  /// Những người chỉ hiện như vợ/chồng cạnh người khác.
  final Set<String> spouseOnlyIds;

  /// Cảnh báo dữ liệu bất thường (chỉ để in khi phát triển).
  final List<String> warnings;
}