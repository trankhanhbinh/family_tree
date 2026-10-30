import 'package:familytree/features/tree/domain/branch.dart';

const int kBranchNameMaxLength = 100;
const int kBranchDescriptionMaxLength = 500;

/// Báo lỗi tiếng Việt, hoặc null nếu tên hợp lệ.
String? validateBranchName(String raw) {
  final name = raw.trim();
  if (name.isEmpty) {
    return 'Hãy nhập tên chi.';
  }
  if (name.length > kBranchNameMaxLength) {
    return 'Tên chi tối đa $kBranchNameMaxLength ký tự.';
  }
  return null;
}

String _normalizeName(String raw) {
  return raw.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

/// Đã có chi CÙNG CẤP (cùng chi cha) trùng tên chưa? Không phân biệt hoa thường.
/// excludeBranchId: bỏ qua chính chi đang sửa.
bool hasSiblingWithName({
  required Iterable<Branch> branches,
  required String? parentBranchId,
  required String name,
  String? excludeBranchId,
}) {
  final wanted = _normalizeName(name);
  return branches.any(
    (b) =>
        b.id != excludeBranchId &&
        b.parentBranchId == parentBranchId &&
        _normalizeName(b.name) == wanted,
  );
}

/// Kiểm tra tên rồi kiểm tra trùng tên cùng cấp.
String? validateBranchNameUnique({
  required Iterable<Branch> branches,
  required String? parentBranchId,
  required String name,
  String? excludeBranchId,
}) {
  final basic = validateBranchName(name);
  if (basic != null) {
    return basic;
  }
  final duplicated = hasSiblingWithName(
    branches: branches,
    parentBranchId: parentBranchId,
    name: name,
    excludeBranchId: excludeBranchId,
  );
  if (duplicated) {
    return 'Cùng cấp đã có chi tên "${name.trim()}". Hãy đặt tên khác.';
  }
  return null;
}

/// Mọi chi con, cháu, ... của branchId (không gồm chính nó).
Set<String> descendantIdsOf(String branchId, Iterable<Branch> branches) {
  final childrenOf = <String, List<String>>{};
  for (final b in branches) {
    final parentId = b.parentBranchId;
    if (parentId != null) {
      childrenOf.putIfAbsent(parentId, () => <String>[]).add(b.id);
    }
  }
  final result = <String>{};
  final queue = <String>[branchId];
  while (queue.isNotEmpty) {
    final current = queue.removeLast();
    for (final childId in childrenOf[current] ?? const <String>[]) {
      if (result.add(childId)) {
        queue.add(childId);
      }
    }
  }
  return result;
}

/// Chuyển chi branchId sang chi cha newParentId (null = thành chi gốc).
/// Trả về câu báo lỗi tiếng Việt, hoặc null nếu chuyển được.
String? validateBranchMove({
  required String branchId,
  required String? newParentId,
  required Iterable<Branch> branches,
}) {
  if (newParentId == branchId) {
    return 'Không thể chuyển chi vào chính nó.';
  }
  if (newParentId != null &&
      descendantIdsOf(branchId, branches).contains(newParentId)) {
    return 'Không thể chuyển chi vào nhánh con của chính nó.';
  }
  Branch? current;
  for (final b in branches) {
    if (b.id == branchId) {
      current = b;
      break;
    }
  }
  if (current != null && current.parentBranchId == newParentId) {
    return 'Chi này đang nằm ở vị trí đó rồi.';
  }
  return null;
}

/// sort_order cho chi mới (hoặc chi vừa chuyển cha): lớn nhất trong cùng cấp + 1,
/// chưa có chi nào cùng cấp thì 0.
int nextSortOrder({
  required Iterable<Branch> branches,
  required String? parentBranchId,
  String? excludeBranchId,
}) {
  int? maxOrder;
  for (final b in branches) {
    if (b.id == excludeBranchId || b.parentBranchId != parentBranchId) {
      continue;
    }
    if (maxOrder == null || b.sortOrder > maxOrder) {
      maxOrder = b.sortOrder;
    }
  }
  return maxOrder == null ? 0 : maxOrder + 1;
}