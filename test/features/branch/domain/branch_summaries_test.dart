import 'package:flutter_test/flutter_test.dart';

import 'package:familytree/features/branch/domain/branch_summaries.dart';
import 'package:familytree/features/tree/domain/branch.dart';

const Branch _original = Branch(
  id: 'b1',
  name: 'Chi Cũ',
  description: 'Mô tả cũ',
  sortOrder: 0,
);

void main() {
  test('thêm chi: ghi tên (đã bỏ khoảng trắng) và đường dẫn chi cha', () {
    expect(
      describeBranchCreate(name: ' Nhánh 3 ', parentPath: 'Chi Cả'),
      'Thêm chi "Nhánh 3"\nThuộc: Chi Cả',
    );
  });

  test('thêm chi gốc: ghi "Chi gốc"', () {
    expect(
      describeBranchCreate(name: 'Chi Ba', parentPath: null),
      'Thêm chi "Chi Ba"\nThuộc: Chi gốc (không thuộc chi nào)',
    );
  });

  test('đổi tên: một dòng "Tên chi: cũ → mới"', () {
    final lines = describeBranchRename(
      original: _original,
      payload: {'name': 'Chi Mới'},
    );
    expect(lines, ['Tên chi: Chi Cũ → Chi Mới']);
  });

  test('mô tả cũ trống hiện "(trống)"', () {
    const original = Branch(id: 'b2', name: 'A', sortOrder: 0);
    final lines = describeBranchRename(
      original: original,
      payload: {'description': 'Mới'},
    );
    expect(lines, ['Mô tả: (trống) → Mới']);
  });

  test('thứ tự dòng cố định: tên rồi mô tả', () {
    final lines = describeBranchRename(
      original: _original,
      payload: {'description': 'D', 'name': 'N'},
    );
    expect(lines.length, 2);
    expect(lines[0], startsWith('Tên chi:'));
    expect(lines[1], startsWith('Mô tả:'));
  });

  test('mô tả cũ dài hơn 60 ký tự bị cắt, mô tả mới null hiện "(trống)"', () {
    final original = Branch(
      id: 'b3',
      name: 'A',
      description: 'a' * 80,
      sortOrder: 0,
    );
    final lines = describeBranchRename(
      original: original,
      payload: {'description': null},
    );
    expect(lines, ['Mô tả: ${'a' * 60}… → (trống)']);
  });
}