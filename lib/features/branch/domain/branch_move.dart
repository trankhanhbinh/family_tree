import 'package:familytree/features/branch/domain/branch_rules.dart';
import 'package:familytree/features/branch/domain/branch_usage.dart';
import 'package:familytree/features/tree/domain/branch.dart';

/// Kiểm tra đầy đủ trước khi chuyển chi: vòng, cùng vị trí, trùng tên ở chi đích.
/// Trả về câu báo lỗi tiếng Việt, hoặc null nếu chuyển được.
String? validateBranchMoveTarget({
  required Branch branch,
  required String? newParentId,
  required Iterable<Branch> branches,
}) {
  final moveError = validateBranchMove(
    branchId: branch.id,
    newParentId: newParentId,
    branches: branches,
  );
  if (moveError != null) {
    return moveError;
  }
  final duplicated = hasSiblingWithName(
    branches: branches,
    parentBranchId: newParentId,
    name: branch.name,
    excludeBranchId: branch.id,
  );
  if (duplicated) {
    return 'Chi đích đã có chi cùng tên "${branch.name.trim()}". '
        'Hãy đổi tên một trong hai chi trước khi chuyển.';
  }
  return null;
}

/// Số người đang sống trong chi này và mọi chi con cháu của nó.
int countLivingInSubtree({
  required String branchId,
  required Iterable<Branch> branches,
  required BranchUsage usage,
}) {
  var total = usage.livingCount(branchId);
  for (final id in descendantIdsOf(branchId, branches)) {
    total += usage.livingCount(id);
  }
  return total;
}

/// Nội dung hộp thoại xác nhận khi chuyển chi.
/// fromPath / toPath là đường dẫn chi CHA (null = chi gốc).
String describeBranchMove({
  required String name,
  required String? fromPath,
  required String? toPath,
  required int descendantBranchCount,
  required int livingPeopleCount,
}) {
  const rootText = 'Chi gốc (không thuộc chi nào)';
  final lines = <String>[
    'Chuyển chi "${name.trim()}"',
    'Từ: ${fromPath ?? rootText}',
    'Sang: ${toPath ?? rootText}',
  ];
  final followers = <String>[];
  if (descendantBranchCount > 0) {
    followers.add('$descendantBranchCount chi con');
  }
  if (livingPeopleCount > 0) {
    followers.add('$livingPeopleCount người');
  }
  if (followers.isNotEmpty) {
    lines.add('Đi theo: ${followers.join(', ')}');
  }
  return lines.join('\n');
}