import 'package:flutter_test/flutter_test.dart';
import 'package:familytree/features/person/domain/branch_path.dart';
import 'package:familytree/features/tree/domain/branch.dart';

Branch _branch(String id, String name, {String? parentId}) {
  return Branch.fromJson({
    'id': id,
    'name': name,
    'description': null,
    'parent_branch_id': parentId,
    'sort_order': 0,
  });
}

void main() {
  test('đường dẫn chi/nhánh lồng nhau từ gốc xuống', () {
    final branches = [
      _branch('b1', 'Chi Nhất'),
      _branch('b3', 'Nhánh Nhất-1', parentId: 'b1'),
    ];
    expect(branchPathOf('b3', branches), 'Chi Nhất › Nhánh Nhất-1');
    expect(branchPathOf('b1', branches), 'Chi Nhất');
  });

  test('không có chi hoặc không tìm thấy thì trả về null', () {
    final branches = [_branch('b1', 'Chi Nhất')];
    expect(branchPathOf(null, branches), isNull);
    expect(branchPathOf('khong-co', branches), isNull);
  });

  test('chặn vòng lặp dữ liệu hỏng', () {
    final branches = [
      _branch('x', 'X', parentId: 'y'),
      _branch('y', 'Y', parentId: 'x'),
    ];
    expect(branchPathOf('x', branches), 'Y › X');
  });
}