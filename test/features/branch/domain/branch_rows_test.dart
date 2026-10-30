import 'package:flutter_test/flutter_test.dart';

import 'package:familytree/features/branch/domain/branch_rows.dart';
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

void main() {
  test('không có chi thì danh sách rỗng', () {
    final rows = buildBranchRows(branches: const [], usage: BranchUsage.empty());
    expect(rows, isEmpty);
  });

  test('anh em sắp theo sort_order rồi theo tên', () {
    final rows = buildBranchRows(
      branches: [
        _b('x', sort: 2),
        _b('a', sort: 1, name: 'Chi B'),
        _b('c', sort: 1, name: 'Chi A'),
      ],
      usage: BranchUsage.empty(),
    );
    expect(rows.map((r) => r.branch.id).toList(), ['c', 'a', 'x']);
  });

  test('cha trước con, có độ thụt lề và cờ hasChildren', () {
    final rows = buildBranchRows(
      branches: [
        _b('g', parent: 'c1'),
        _b('c1', parent: 'r'),
        _b('r'),
      ],
      usage: BranchUsage.empty(),
    );
    expect(rows.map((r) => r.branch.id).toList(), ['r', 'c1', 'g']);
    expect(rows.map((r) => r.depth).toList(), [0, 1, 2]);
    expect(rows.map((r) => r.hasChildren).toList(), [true, true, false]);
  });

  test('livingCount chỉ đếm người đang sống, trực tiếp trong chi', () {
    final usage = BranchUsage.fromMembers(const [
      BranchMember(id: 'p1', fullName: 'A', branchId: 'r', isDeleted: false),
      BranchMember(id: 'p2', fullName: 'B', branchId: 'r', isDeleted: false),
      BranchMember(id: 'p3', fullName: 'C', branchId: 'c', isDeleted: true),
    ]);
    final rows = buildBranchRows(
      branches: [_b('r'), _b('c', parent: 'r')],
      usage: usage,
    );
    expect(rows[0].livingCount, 2);
    expect(rows[1].livingCount, 0);
  });

  test('chi có cha không còn trong danh sách thì thành chi gốc', () {
    final rows = buildBranchRows(
      branches: [_b('o', parent: 'missing')],
      usage: BranchUsage.empty(),
    );
    expect(rows.length, 1);
    expect(rows.first.depth, 0);
  });

  test('excludeIds loại chi được chỉ định; chi con của chi bị loại thành chi gốc', () {
    final rows = buildBranchRows(
      branches: [
        _b('r'),
        _b('c1', parent: 'r'),
        _b('g', parent: 'c1'),
      ],
      usage: BranchUsage.empty(),
      excludeIds: {'r', 'c1'},
    );
    expect(rows.map((r) => r.branch.id).toList(), ['g']);
    expect(rows.first.depth, 0);
  });

  test('dữ liệu bị vòng thì không treo và không hiện', () {
    final rows = buildBranchRows(
      branches: [
        _b('a', parent: 'b'),
        _b('b', parent: 'a'),
      ],
      usage: BranchUsage.empty(),
    );
    expect(rows, isEmpty);
  });
}