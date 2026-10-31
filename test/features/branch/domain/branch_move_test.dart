import 'package:flutter_test/flutter_test.dart';

import 'package:familytree/features/branch/domain/branch_move.dart';
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

final Branch _c1 = _b('c1', parent: 'r1', name: 'Nhánh 1');
final Branch _g1 = _b('g1', parent: 'c1', name: 'Nhánh con');

final List<Branch> _branches = [
  _b('r1', name: 'Chi Nhất'),
  _b('r2', name: 'Chi Nhì'),
  _b('r3', name: 'nhánh 1'),
  _c1,
  _b('c2', parent: 'r1', name: 'Nhánh 2'),
  _g1,
  _b('d', parent: 'r2', name: 'NHÁNH 1'),
];

void main() {
  group('validateBranchMoveTarget', () {
    test('lỗi của validateBranchMove được chuyển tiếp (vào chính nó)', () {
      expect(
        validateBranchMoveTarget(
          branch: _c1,
          newParentId: 'c1',
          branches: _branches,
        ),
        'Không thể chuyển chi vào chính nó.',
      );
    });

    test('chi đích đã có chi cùng tên (không phân biệt hoa thường)', () {
      expect(
        validateBranchMoveTarget(
          branch: _c1,
          newParentId: 'r2',
          branches: _branches,
        ),
        'Chi đích đã có chi cùng tên "Nhánh 1". '
        'Hãy đổi tên một trong hai chi trước khi chuyển.',
      );
    });

    test('chuyển thành chi gốc nhưng đã có chi gốc cùng tên thì chặn', () {
      expect(
        validateBranchMoveTarget(
          branch: _c1,
          newParentId: null,
          branches: _branches,
        ),
        isNotNull,
      );
    });

    test('chuyển hợp lệ thì null', () {
      expect(
        validateBranchMoveTarget(
          branch: _g1,
          newParentId: 'r2',
          branches: _branches,
        ),
        isNull,
      );
    });
  });

  group('countLivingInSubtree', () {
    final usage = BranchUsage.fromMembers([
      _m('p1', 'c1'),
      _m('p2', 'g1'),
      _m('p3', 'c1', deleted: true),
      _m('p4', 'c2'),
    ]);

    test('đếm người đang sống của chi và mọi chi con cháu', () {
      expect(
        countLivingInSubtree(branchId: 'c1', branches: _branches, usage: usage),
        2,
      );
      expect(
        countLivingInSubtree(branchId: 'r1', branches: _branches, usage: usage),
        3,
      );
    });

    test('chi không có ai thì 0', () {
      expect(
        countLivingInSubtree(branchId: 'r2', branches: _branches, usage: usage),
        0,
      );
    });
  });

  group('describeBranchMove', () {
    test('đủ các dòng, có dòng "Đi theo"', () {
      expect(
        describeBranchMove(
          name: ' Nhánh 1 ',
          fromPath: 'Chi Nhất',
          toPath: 'Chi Nhì',
          descendantBranchCount: 2,
          livingPeopleCount: 5,
        ),
        'Chuyển chi "Nhánh 1"\n'
        'Từ: Chi Nhất\n'
        'Sang: Chi Nhì\n'
        'Đi theo: 2 chi con, 5 người',
      );
    });

    test('từ chi gốc, không ai đi theo thì bỏ dòng "Đi theo"', () {
      expect(
        describeBranchMove(
          name: 'A',
          fromPath: null,
          toPath: 'Chi Nhì',
          descendantBranchCount: 0,
          livingPeopleCount: 0,
        ),
        'Chuyển chi "A"\n'
        'Từ: Chi gốc (không thuộc chi nào)\n'
        'Sang: Chi Nhì',
      );
    });
  });
}