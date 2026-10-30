import 'package:flutter_test/flutter_test.dart';

import 'package:familytree/features/branch/domain/branch_changes.dart';
import 'package:familytree/features/tree/domain/branch.dart';

const Branch _original = Branch(
  id: 'b1',
  name: 'Chi Cũ',
  description: 'Mô tả cũ',
  sortOrder: 0,
);

void main() {
  test('tạo chi: đủ cột, đã bỏ khoảng trắng', () {
    final payload = buildBranchCreatePayload(
      name: ' Chi Ba ',
      description: ' Mô tả ',
      parentBranchId: 'r1',
      sortOrder: 3,
    );
    expect(payload, {
      'name': 'Chi Ba',
      'description': 'Mô tả',
      'parent_branch_id': 'r1',
      'sort_order': 3,
    });
  });

  test('tạo chi gốc, mô tả trống thì description = null', () {
    final payload = buildBranchCreatePayload(
      name: 'Chi Ba',
      description: '  ',
      parentBranchId: null,
      sortOrder: 0,
    );
    expect(payload, {
      'name': 'Chi Ba',
      'description': null,
      'parent_branch_id': null,
      'sort_order': 0,
    });
  });

  test('đổi tên: chỉ có khóa name', () {
    final payload = buildBranchRenamePayload(
      original: _original,
      name: ' Chi Mới ',
      description: 'Mô tả cũ',
    );
    expect(payload, {'name': 'Chi Mới'});
  });

  test('xóa trống mô tả: description = null', () {
    final payload = buildBranchRenamePayload(
      original: _original,
      name: 'Chi Cũ',
      description: '',
    );
    expect(payload.length, 1);
    expect(payload.containsKey('description'), isTrue);
    expect(payload['description'], isNull);
  });

  test('không đổi gì (chỉ khác khoảng trắng) thì rỗng', () {
    final payload = buildBranchRenamePayload(
      original: _original,
      name: '  Chi Cũ ',
      description: ' Mô tả cũ ',
    );
    expect(payload, isEmpty);
  });

  test('chuyển chi: parent_branch_id và sort_order', () {
    expect(
      buildBranchMovePayload(newParentId: 'r2', newSortOrder: 4),
      {'parent_branch_id': 'r2', 'sort_order': 4},
    );
    expect(
      buildBranchMovePayload(newParentId: null, newSortOrder: 0),
      {'parent_branch_id': null, 'sort_order': 0},
    );
  });

  test('đổi chi của một người: có chi mới hoặc null', () {
    expect(buildPersonBranchPayload(newBranchId: 'b2'), {'branch_id': 'b2'});
    expect(buildPersonBranchPayload(newBranchId: null), {'branch_id': null});
  });
}