import 'package:familytree/features/branch/domain/branch_rows.dart';
import 'package:familytree/features/branch/domain/branch_usage.dart';
import 'package:familytree/features/tree/domain/branch.dart';

/// Những thứ đang cản việc xóa một chi.
class BranchDeleteBlockers {
  const BranchDeleteBlockers({
    required this.childBranches,
    required this.livingPeople,
    required this.deletedPeople,
  });

  final List<Branch> childBranches;
  final List<BranchMember> livingPeople;
  final List<BranchMember> deletedPeople;

  bool get canDelete =>
      childBranches.isEmpty && livingPeople.isEmpty && deletedPeople.isEmpty;
}

BranchDeleteBlockers checkBranchDelete({
  required String branchId,
  required Iterable<Branch> branches,
  required BranchUsage usage,
}) {
  final children = branches.where((b) => b.parentBranchId == branchId).toList()
    ..sort(compareBranches);
  return BranchDeleteBlockers(
    childBranches: children,
    livingPeople: usage.livingIn(branchId),
    deletedPeople: usage.deletedIn(branchId),
  );
}

/// "A, B, C" hoặc "A, B, ... và 3 người khác" khi quá giới hạn.
String summarizeNames(
  List<String> names, {
  int limit = 10,
  String unit = 'người',
}) {
  if (names.length <= limit) {
    return names.join(', ');
  }
  final shown = names.take(limit).join(', ');
  return '$shown và ${names.length - limit} $unit khác';
}