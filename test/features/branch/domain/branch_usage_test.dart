import 'package:flutter_test/flutter_test.dart';

import 'package:familytree/features/branch/domain/branch_usage.dart';

BranchMember _m(
  String id,
  String branchId, {
  String name = 'Người',
  bool deleted = false,
}) {
  return BranchMember(
    id: id,
    fullName: name,
    branchId: branchId,
    isDeleted: deleted,
  );
}

void main() {
  test('fromJson: người đang sống', () {
    final m = BranchMember.fromJson({
      'id': 'p1',
      'full_name': 'Nguyễn Văn A',
      'branch_id': 'b1',
      'deleted_at': null,
    });
    expect(m.id, 'p1');
    expect(m.fullName, 'Nguyễn Văn A');
    expect(m.branchId, 'b1');
    expect(m.isDeleted, isFalse);
  });

  test('fromJson: người đã xóa mềm', () {
    final m = BranchMember.fromJson({
      'id': 'p2',
      'full_name': 'Nguyễn Văn B',
      'branch_id': 'b1',
      'deleted_at': '2026-10-01T00:00:00+00:00',
    });
    expect(m.isDeleted, isTrue);
  });

  test('gom theo chi và tách người sống / đã xóa', () {
    final usage = BranchUsage.fromMembers([
      _m('p1', 'b1'),
      _m('p2', 'b1', deleted: true),
      _m('p3', 'b2'),
      _m('p4', 'b1'),
    ]);
    expect(usage.livingCount('b1'), 2);
    expect(usage.deletedCount('b1'), 1);
    expect(usage.livingCount('b2'), 1);
    expect(usage.deletedCount('b2'), 0);
  });

  test('sắp theo tên (không phân biệt hoa thường) rồi theo id', () {
    final usage = BranchUsage.fromMembers([
      _m('p3', 'b1', name: 'bình'),
      _m('p2', 'b1', name: 'An'),
      _m('p1', 'b1', name: 'An'),
    ]);
    expect(usage.livingIn('b1').map((m) => m.id).toList(), ['p1', 'p2', 'p3']);
  });

  test('chi không có ai thì trả danh sách rỗng', () {
    final usage = BranchUsage.empty();
    expect(usage.livingIn('x'), isEmpty);
    expect(usage.deletedIn('x'), isEmpty);
    expect(usage.livingCount('x'), 0);
  });
}