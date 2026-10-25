import 'package:familytree/features/tree/domain/branch.dart';

/// Đường dẫn chi/nhánh từ gốc xuống, ví dụ "Chi Nhất › Nhánh Nhất-1".
/// Trả về null nếu không có chi hoặc không tìm thấy. Có chặn vòng lặp.
String? branchPathOf(String? branchId, Iterable<Branch> branches) {
  if (branchId == null) {
    return null;
  }
  final byId = {for (final b in branches) b.id: b};
  final names = <String>[];
  final seen = <String>{};
  String? currentId = branchId;
  while (currentId != null && seen.add(currentId)) {
    final branch = byId[currentId];
    if (branch == null) {
      break;
    }
    names.add(branch.name);
    currentId = branch.parentBranchId;
  }
  if (names.isEmpty) {
    return null;
  }
  return names.reversed.join(' › ');
}