import 'package:flutter_test/flutter_test.dart';

import 'package:familytree/features/branch/domain/branch_rules.dart';
import 'package:familytree/features/tree/domain/branch.dart';

Branch _b(String id, {String? parent, int sort = 0, String? name}) {
  return Branch(
    id: id,
    name: name ?? 'Chi $id',
    parentBranchId: parent,
    sortOrder: sort,
  );
}

final List<Branch> _branches = [
  _b('r1', name: 'Chi Nhất'),
  _b('r2', name: 'Chi Nhì'),
  _b('c1', parent: 'r1', name: 'Nhánh 1'),
  _b('c2', parent: 'r1', name: 'Nhánh 2'),
  _b('g1', parent: 'c1', name: 'Nhánh con'),
];

void main() {
  group('validateBranchName', () {
    test('rỗng thì báo lỗi', () {
      expect(validateBranchName('   '), 'Hãy nhập tên chi.');
    });

    test('tên hợp lệ thì null', () {
      expect(validateBranchName(' Chi Ba '), isNull);
    });

    test('quá 100 ký tự thì báo lỗi', () {
      expect(validateBranchName('a' * 101), 'Tên chi tối đa 100 ký tự.');
    });
  });

  group('hasSiblingWithName', () {
    test('trùng ở cấp gốc, không phân biệt hoa thường và khoảng trắng', () {
      expect(
        hasSiblingWithName(
          branches: _branches,
          parentBranchId: null,
          name: '  chi  nhất ',
        ),
        isTrue,
      );
    });

    test('cùng tên nhưng khác cấp thì không trùng', () {
      expect(
        hasSiblingWithName(
          branches: _branches,
          parentBranchId: 'r2',
          name: 'Chi Nhất',
        ),
        isFalse,
      );
    });

    test('bỏ qua chính chi đang sửa', () {
      expect(
        hasSiblingWithName(
          branches: _branches,
          parentBranchId: 'r1',
          name: 'Nhánh 1',
          excludeBranchId: 'c1',
        ),
        isFalse,
      );
    });

    test('trùng ở cấp con', () {
      expect(
        hasSiblingWithName(
          branches: _branches,
          parentBranchId: 'r1',
          name: 'nhánh 2',
        ),
        isTrue,
      );
    });
  });

  group('validateBranchNameUnique', () {
    test('tên rỗng thì báo lỗi tên trước', () {
      expect(
        validateBranchNameUnique(
          branches: _branches,
          parentBranchId: null,
          name: '',
        ),
        'Hãy nhập tên chi.',
      );
    });

    test('trùng tên thì báo lỗi trùng (tên đã bỏ khoảng trắng)', () {
      expect(
        validateBranchNameUnique(
          branches: _branches,
          parentBranchId: 'r1',
          name: ' Nhánh 2 ',
        ),
        'Cùng cấp đã có chi tên "Nhánh 2". Hãy đặt tên khác.',
      );
    });

    test('tên mới hợp lệ thì null', () {
      expect(
        validateBranchNameUnique(
          branches: _branches,
          parentBranchId: 'r1',
          name: 'Nhánh 3',
        ),
        isNull,
      );
    });
  });

  group('descendantIdsOf', () {
    test('trả về mọi chi con cháu, không gồm chính nó', () {
      expect(descendantIdsOf('r1', _branches), {'c1', 'c2', 'g1'});
    });

    test('chi lá thì rỗng', () {
      expect(descendantIdsOf('g1', _branches), isEmpty);
    });
  });

  group('validateBranchMove', () {
    test('chuyển vào chính nó thì báo lỗi', () {
      expect(
        validateBranchMove(
          branchId: 'c1',
          newParentId: 'c1',
          branches: _branches,
        ),
        'Không thể chuyển chi vào chính nó.',
      );
    });

    test('chuyển vào nhánh con của chính nó thì báo lỗi', () {
      expect(
        validateBranchMove(
          branchId: 'r1',
          newParentId: 'g1',
          branches: _branches,
        ),
        'Không thể chuyển chi vào nhánh con của chính nó.',
      );
    });

    test('chuyển vào đúng chi cha hiện tại thì báo lỗi', () {
      expect(
        validateBranchMove(
          branchId: 'c1',
          newParentId: 'r1',
          branches: _branches,
        ),
        'Chi này đang nằm ở vị trí đó rồi.',
      );
    });

    test('chuyển thành chi gốc thì hợp lệ', () {
      expect(
        validateBranchMove(
          branchId: 'c1',
          newParentId: null,
          branches: _branches,
        ),
        isNull,
      );
    });

    test('chuyển sang chi khác hợp lệ thì null', () {
      expect(
        validateBranchMove(
          branchId: 'g1',
          newParentId: 'r2',
          branches: _branches,
        ),
        isNull,
      );
    });
  });

  group('nextSortOrder', () {
    test('chưa có chi nào cùng cấp thì 0', () {
      expect(nextSortOrder(branches: _branches, parentBranchId: 'r2'), 0);
    });

    test('lớn nhất trong cùng cấp + 1', () {
      final branches = [
        _b('r1'),
        _b('c1', parent: 'r1', sort: 3),
        _b('c2', parent: 'r1', sort: 5),
        _b('x', parent: 'r2', sort: 9),
      ];
      expect(nextSortOrder(branches: branches, parentBranchId: 'r1'), 6);
    });

    test('bỏ qua chi được loại trừ', () {
      final branches = [
        _b('r1'),
        _b('c1', parent: 'r1', sort: 3),
        _b('c2', parent: 'r1', sort: 5),
      ];
      expect(
        nextSortOrder(
          branches: branches,
          parentBranchId: 'r1',
          excludeBranchId: 'c2',
        ),
        4,
      );
    });
  });
}