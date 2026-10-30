import 'package:flutter_test/flutter_test.dart';

import 'package:familytree/features/branch/domain/branch_delete_check.dart';
import 'package:familytree/features/branch/domain/branch_usage.dart';
import 'package:familytree/features/tree/domain/branch.dart';

Branch _b(String id, {String? parent, int sort = 0, String? name}) {
  return Branch(
    id: id,
    name: name ?? 'Chi $id',
    parentBranchId: parent,
    sortOrder: sort,
  );
}

BranchMember _m(String id, String branchId, {bool deleted = false}) {
  return BranchMember(
    id: id,
    fullName: 'Người $id',
    branchId: branchId,
    isDeleted: deleted,
  );
}

final List<Branch> _branches = [
  _b('r', name: 'Chi Cả'),
  _b('c2', parent: 'r', sort: 2, name: 'Nhánh 2'),
  _b('c1', parent: 'r', sort: 1, name: 'Nhánh 1'),
  _b('other'),
];

void main() {
  test('chi trống hoàn toàn thì xóa được', () {
    final result = checkBranchDelete(
      branchId: 'c1',
      branches: _branches,
      usage: BranchUsage.empty(),
    );
    expect(result.canDelete, isTrue);
    expect(result.childBranches, isEmpty);
    expect(result.livingPeople, isEmpty);
    expect(result.deletedPeople, isEmpty);
  });

  test('còn chi con thì chặn, chi con sắp theo thứ tự hiển thị', () {
    final result = checkBranchDelete(
      branchId: 'r',
      branches: _branches,
      usage: BranchUsage.empty(),
    );
    expect(result.canDelete, isFalse);
    expect(result.childBranches.map((b) => b.id).toList(), ['c1', 'c2']);
  });

  test('còn người đang sống thì chặn', () {
    final result = checkBranchDelete(
      branchId: 'c1',
      branches: _branches,
      usage: BranchUsage.fromMembers([_m('p1', 'c1'), _m('p2', 'c1')]),
    );
    expect(result.canDelete, isFalse);
    expect(result.livingPeople.length, 2);
  });

  test('chỉ còn người đã xóa mềm vẫn chặn', () {
    final result = checkBranchDelete(
      branchId: 'c1',
      branches: _branches,
      usage: BranchUsage.fromMembers([_m('p1', 'c1', deleted: true)]),
    );
    expect(result.canDelete, isFalse);
    expect(result.livingPeople, isEmpty);
    expect(result.deletedPeople.length, 1);
  });

  test('người thuộc chi khác không ảnh hưởng', () {
    final result = checkBranchDelete(
      branchId: 'c1',
      branches: _branches,
      usage: BranchUsage.fromMembers([_m('p1', 'other')]),
    );
    expect(result.canDelete, isTrue);
  });

  test('summarizeNames: không quá giới hạn thì nối bằng dấu phẩy', () {
    expect(summarizeNames(['A', 'B']), 'A, B');
    expect(summarizeNames(['A', 'B', 'C'], limit: 3), 'A, B, C');
  });

  test('summarizeNames: quá giới hạn thì ghi "và N người khác"', () {
    final names = List.generate(12, (i) => 'N${i + 1}');
    expect(
      summarizeNames(names),
      'N1, N2, N3, N4, N5, N6, N7, N8, N9, N10 và 2 người khác',
    );
  });
}