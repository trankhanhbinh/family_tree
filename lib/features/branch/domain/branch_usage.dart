/// Một người có gắn chi (kể cả người đã xóa mềm). Dùng cho màn quản lý chi.
class BranchMember {
  const BranchMember({
    required this.id,
    required this.fullName,
    required this.branchId,
    required this.isDeleted,
  });

  final String id;
  final String fullName;
  final String branchId;
  final bool isDeleted;

  factory BranchMember.fromJson(Map<String, dynamic> json) {
    return BranchMember(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      branchId: json['branch_id'] as String,
      isDeleted: json['deleted_at'] != null,
    );
  }
}

/// Ai đang thuộc chi nào, tách người đang sống / người đã xóa mềm.
class BranchUsage {
  BranchUsage._(this._living, this._deleted);

  factory BranchUsage.fromMembers(Iterable<BranchMember> members) {
    final living = <String, List<BranchMember>>{};
    final deleted = <String, List<BranchMember>>{};
    for (final member in members) {
      final target = member.isDeleted ? deleted : living;
      target.putIfAbsent(member.branchId, () => <BranchMember>[]).add(member);
    }
    for (final list in [...living.values, ...deleted.values]) {
      list.sort(_compareMembers);
    }
    return BranchUsage._(living, deleted);
  }

  factory BranchUsage.empty() => BranchUsage.fromMembers(const []);

  final Map<String, List<BranchMember>> _living;
  final Map<String, List<BranchMember>> _deleted;

  List<BranchMember> livingIn(String branchId) =>
      _living[branchId] ?? const <BranchMember>[];

  List<BranchMember> deletedIn(String branchId) =>
      _deleted[branchId] ?? const <BranchMember>[];

  int livingCount(String branchId) => livingIn(branchId).length;

  int deletedCount(String branchId) => deletedIn(branchId).length;
}

int _compareMembers(BranchMember a, BranchMember b) {
  final byName = a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
  return byName != 0 ? byName : a.id.compareTo(b.id);
}