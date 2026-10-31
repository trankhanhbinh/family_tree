import 'package:flutter_test/flutter_test.dart';
import 'package:familytree/features/history/domain/history_describer.dart';
import 'package:familytree/features/history/domain/history_entry.dart';
import 'package:familytree/features/person/domain/branch_path.dart';
import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/tree/domain/branch.dart';
import 'package:familytree/features/tree/domain/tree_data.dart';

const String _t0 = '2026-10-28T06:48:25.087756+00:00';

HistoryEntry _entry({
  String entityType = 'person',
  String action = 'update',
  String entityId = 'a1',
  Map<String, dynamic>? before,
  Map<String, dynamic>? after,
}) {
  return HistoryEntry.fromJson({
    'id': 'h1',
    'entity_type': entityType,
    'entity_id': entityId,
    'action': action,
    'before_data': before,
    'after_data': after,
    'actor_name': 'Admin',
    'actor_user_id': 'u1',
    'request_id': null,
    'created_at': _t0,
  });
}

String? _names(Object? id) {
  return switch (id) {
    'p1' => 'Nguyễn Văn A',
    'c1' => 'Nguyễn Thị B',
    _ => null,
  };
}

DescribedHistoryEntry _describe(HistoryEntry entry) {
  return describeHistoryEntry(entry, nameOf: _names, branches: const []);
}

Person _person(String id, String fullName) {
  return Person.fromJson({
    'id': id,
    'full_name': fullName,
    'other_name': null,
    'gender': 'male',
    'branch_id': null,
    'generation': 1,
    'birth_date': null,
    'birth_year': null,
    'birth_place': null,
    'is_alive': true,
    'death_date': null,
    'death_year': null,
    'burial_place': null,
    'memorial_lunar_day': null,
    'memorial_lunar_month': null,
    'memorial_is_leap': false,
    'notes': null,
    'deleted_at': null,
  });
}

const Branch _chiNhat = Branch(id: 'b1', name: 'Chi Nhất', sortOrder: 0);
const Branch _chiHai = Branch(id: 'b2', name: 'Chi Hai', sortOrder: 1);
const Branch _nhanhCon = Branch(
  id: 'b3',
  name: 'Nhánh Nhất-1',
  parentBranchId: 'b1',
  sortOrder: 0,
);

DescribedHistoryEntry _describeWith(
  HistoryEntry entry,
  List<Branch> branches,
) {
  return describeHistoryEntry(entry, nameOf: _names, branches: branches);
}

TreeData _treeOf(List<Branch> branches) {
  return TreeData(
    people: const [],
    branches: branches,
    parentChildren: const [],
    marriages: const [],
    photos: const [],
  );
}

void main() {
  test('thêm người: tiêu đề và các dòng có giá trị', () {
    final result = _describe(
      _entry(
        action: 'create',
        after: {
          'id': 'a1',
          'full_name': 'Nguyễn Văn B',
          'other_name': null,
          'gender': 'male',
          'birth_year': 1990,
          'is_alive': true,
          'memorial_is_leap': false,
        },
      ),
    );
    expect(result.title, 'Thêm người: Nguyễn Văn B');
    expect(result.details, ['Giới tính: Nam', 'Năm sinh: 1990']);
  });

  test('sửa người: "cũ → mới", bỏ qua updated_at', () {
    final result = _describe(
      _entry(
        before: {
          'full_name': 'Nguyễn Văn Phúc',
          'birth_date': '1988-04-18',
          'birth_year': 1988,
          'updated_at': '2026-10-22T16:14:50.062434+00:00',
        },
        after: {
          'full_name': 'Nguyễn Văn Phúc',
          'birth_date': '1989-04-18',
          'birth_year': 1989,
          'updated_at': '2026-10-28T06:48:25.087756+00:00',
        },
      ),
    );
    expect(result.title, 'Sửa thông tin: Nguyễn Văn Phúc');
    expect(result.details, [
      'Ngày sinh: 18/04/1988 → 18/04/1989',
      'Năm sinh: 1988 → 1989',
    ]);
  });

  test('sửa người: chỉ đổi cột không có nhãn thì không có dòng chi tiết', () {
    final result = _describe(
      _entry(
        before: {'full_name': 'Nguyễn Văn A', 'updated_at': 'x'},
        after: {'full_name': 'Nguyễn Văn A', 'updated_at': 'y'},
      ),
    );
    expect(result.details, isEmpty);
  });

  test('xóa mềm người', () {
    final result = _describe(
      _entry(
        action: 'delete',
        before: {'full_name': 'Nguyễn Thị An', 'deleted_at': null},
        after: {
          'full_name': 'Nguyễn Thị An',
          'deleted_at': '2026-10-27T20:43:39.640461+00:00',
        },
      ),
    );
    expect(result.title, 'Xóa người: Nguyễn Thị An');
    expect(result.details, ['Người này đã bị xóa khỏi gia phả.']);
  });

  test('khôi phục người', () {
    final result = _describe(
      _entry(
        action: 'restore',
        before: {
          'full_name': 'Nguyễn Thị An',
          'deleted_at': '2026-10-27T20:43:39.640461+00:00',
        },
        after: {'full_name': 'Nguyễn Thị An', 'deleted_at': null},
      ),
    );
    expect(result.title, 'Khôi phục người: Nguyễn Thị An');
    expect(result.details, ['Người này đã được đưa trở lại gia phả.']);
  });

  test('gỡ quan hệ cha mẹ - con (xóa thật, after = null)', () {
    final result = _describe(
      _entry(
        entityType: 'parent_child',
        action: 'delete',
        before: {
          'parent_id': 'p1',
          'child_id': 'c1',
          'relation_type': 'adopted',
        },
      ),
    );
    expect(
      result.title,
      'Gỡ quan hệ: Nguyễn Văn A là cha/mẹ của Nguyễn Thị B',
    );
  });

  test('gắn quan hệ con nuôi', () {
    final result = _describe(
      _entry(
        entityType: 'parent_child',
        action: 'create',
        after: {
          'parent_id': 'p1',
          'child_id': 'c1',
          'relation_type': 'adopted',
        },
      ),
    );
    expect(result.title, 'Gắn Nguyễn Thị B là con nuôi của Nguyễn Văn A');
  });

  test('đổi loại quan hệ', () {
    final result = _describe(
      _entry(
        entityType: 'parent_child',
        action: 'update',
        before: {
          'parent_id': 'p1',
          'child_id': 'c1',
          'relation_type': 'biological',
        },
        after: {
          'parent_id': 'p1',
          'child_id': 'c1',
          'relation_type': 'adopted',
        },
      ),
    );
    expect(result.title, 'Đổi loại quan hệ: Nguyễn Thị B');
    expect(result.details, [
      'Cha/mẹ: Nguyễn Văn A',
      'Loại quan hệ: Con ruột → Con nuôi',
    ]);
  });

  test('thêm hôn nhân', () {
    final result = _describe(
      _entry(
        entityType: 'marriage',
        action: 'create',
        after: {
          'person1_id': 'p1',
          'person2_id': 'c1',
          'status': 'married',
          'start_date': '2010-01-01',
          'end_date': null,
        },
      ),
    );
    expect(result.title, 'Thêm hôn nhân: Nguyễn Văn A và Nguyễn Thị B');
    expect(result.details, [
      'Tình trạng: Đang kết hôn',
      'Ngày bắt đầu: 01/01/2010',
    ]);
  });

  test('sửa hôn nhân: đổi tình trạng và thêm ngày kết thúc', () {
    final result = _describe(
      _entry(
        entityType: 'marriage',
        action: 'update',
        before: {
          'person1_id': 'p1',
          'person2_id': 'c1',
          'status': 'married',
          'end_date': null,
        },
        after: {
          'person1_id': 'p1',
          'person2_id': 'c1',
          'status': 'divorced',
          'end_date': '2015-05-05',
        },
      ),
    );
    expect(result.title, 'Sửa hôn nhân: Nguyễn Văn A và Nguyễn Thị B');
    expect(result.details, [
      'Tình trạng: Đang kết hôn → Đã ly hôn',
      'Ngày kết thúc: (trống) → 05/05/2015',
    ]);
  });

  test('thêm ảnh có mô tả', () {
    final result = _describe(
      _entry(
        entityType: 'person_photo',
        action: 'create',
        after: {'person_id': 'p1', 'caption': 'Ảnh cưới'},
      ),
    );
    expect(result.title, 'Thêm ảnh cho Nguyễn Văn A');
    expect(result.details, ['Mô tả: Ảnh cưới']);
  });

  test('loại lạ -> "Thay đổi khác"', () {
    final result = _describe(_entry(entityType: 'unknown', action: 'create'));
    expect(result.title, 'Thay đổi khác (unknown, create)');
  });

  test('không tra được tên -> "(không rõ)"', () {
    final result = _describe(
      _entry(
        entityType: 'parent_child',
        action: 'delete',
        before: {'parent_id': 'x', 'child_id': 'y'},
      ),
    );
    expect(result.title, 'Gỡ quan hệ: (không rõ) là cha/mẹ của (không rõ)');
  });

  test('tra tên: ưu tiên tên trong cây, người đã xóa lấy tên từ lịch sử', () {
    final tree = TreeData(
      people: [_person('a1', 'Tên Trong Cây')],
      branches: const [],
      parentChildren: const [],
      marriages: const [],
      photos: const [],
    );
    final lookup = buildHistoryNameLookup(
      tree: tree,
      entries: [
        _entry(entityId: 'a1', before: {'full_name': 'Tên Cũ'}),
        _entry(
          entityId: 'gone',
          action: 'delete',
          before: {'full_name': 'Người Đã Xóa'},
        ),
      ],
    );
    expect(lookup('a1'), 'Tên Trong Cây');
    expect(lookup('gone'), 'Người Đã Xóa');
    expect(lookup('zzz'), isNull);
    expect(lookup(null), isNull);
  });

  test('chi/nhánh bị bỏ trống -> "Không thuộc chi nào"', () {
    final result = _describe(
      _entry(
        before: {'full_name': 'Nguyễn Văn A', 'branch_id': 'b1'},
        after: {'full_name': 'Nguyễn Văn A', 'branch_id': null},
      ),
    );
    expect(result.details.single, endsWith('→ Không thuộc chi nào'));
  });

  
  test('thêm chi gốc: có mô tả, không có dòng chi cha', () {
    final result = _describe(
      _entry(
        entityType: 'branch',
        action: 'create',
        entityId: 'b1',
        after: {
          'id': 'b1',
          'name': 'Chi Nhất',
          'parent_branch_id': null,
          'description': 'Chi trưởng',
          'sort_order': 0,
        },
      ),
    );
    expect(result.title, 'Thêm chi: Chi Nhất');
    expect(result.details, ['Mô tả: Chi trưởng']);
  });

  test('thêm chi con: chi cha hiện bằng đường dẫn', () {
    final result = _describeWith(
      _entry(
        entityType: 'branch',
        action: 'create',
        entityId: 'b3',
        after: {
          'id': 'b3',
          'name': 'Nhánh Nhất-1',
          'parent_branch_id': 'b1',
          'description': null,
          'sort_order': 1,
        },
      ),
      const [_chiNhat],
    );
    expect(result.title, 'Thêm chi: Nhánh Nhất-1');
    expect(result.details, ['Chi cha: Chi Nhất']);
  });

  test('thêm chi con mà chi cha không tra được -> "(chi đã xóa)"', () {
    final result = _describe(
      _entry(
        entityType: 'branch',
        action: 'create',
        after: {'name': 'Nhánh Mồ Côi', 'parent_branch_id': 'zzz'},
      ),
    );
    expect(result.details, ['Chi cha: (chi đã xóa)']);
  });

  test('đổi tên chi', () {
    final result = _describe(
      _entry(
        entityType: 'branch',
        before: {
          'name': 'Chi Nhất',
          'parent_branch_id': null,
          'description': null,
          'sort_order': 0,
          'updated_at': '2026-10-01T00:00:00+00:00',
        },
        after: {
          'name': 'Chi Nhất Mới',
          'parent_branch_id': null,
          'description': null,
          'sort_order': 0,
          'updated_at': '2026-10-28T00:00:00+00:00',
        },
      ),
    );
    expect(result.title, 'Đổi tên chi: Chi Nhất Mới');
    expect(result.details, ['Tên chi: Chi Nhất → Chi Nhất Mới']);
  });

  test('chuyển chi: chỉ hiện chi cha, không hiện thứ tự', () {
    final result = _describeWith(
      _entry(
        entityType: 'branch',
        before: {
          'name': 'Nhánh Nhất-1',
          'parent_branch_id': 'b1',
          'description': null,
          'sort_order': 0,
        },
        after: {
          'name': 'Nhánh Nhất-1',
          'parent_branch_id': 'b2',
          'description': null,
          'sort_order': 3,
        },
      ),
      const [_chiNhat, _chiHai, _nhanhCon],
    );
    expect(result.title, 'Chuyển chi: Nhánh Nhất-1');
    expect(result.details, ['Chi cha: Chi Nhất → Chi Hai']);
  });

  test('chuyển chi ra làm chi gốc', () {
    final result = _describeWith(
      _entry(
        entityType: 'branch',
        before: {'name': 'Nhánh Nhất-1', 'parent_branch_id': 'b1'},
        after: {'name': 'Nhánh Nhất-1', 'parent_branch_id': null},
      ),
      const [_chiNhat, _nhanhCon],
    );
    expect(result.title, 'Chuyển chi: Nhánh Nhất-1');
    expect(result.details, ['Chi cha: Chi Nhất → Chi gốc']);
  });

  test('vừa đổi tên vừa chuyển chi -> "Sửa chi" với 2 dòng', () {
    final result = _describeWith(
      _entry(
        entityType: 'branch',
        before: {'name': 'Nhánh A', 'parent_branch_id': 'b1'},
        after: {'name': 'Nhánh B', 'parent_branch_id': 'b2'},
      ),
      const [_chiNhat, _chiHai],
    );
    expect(result.title, 'Sửa chi: Nhánh B');
    expect(result.details, [
      'Tên chi: Nhánh A → Nhánh B',
      'Chi cha: Chi Nhất → Chi Hai',
    ]);
  });

  test('sửa mô tả chi', () {
    final result = _describe(
      _entry(
        entityType: 'branch',
        before: {'name': 'Chi Nhất', 'description': null},
        after: {'name': 'Chi Nhất', 'description': 'Chi trưởng'},
      ),
    );
    expect(result.title, 'Sửa chi: Chi Nhất');
    expect(result.details, ['Mô tả: (trống) → Chi trưởng']);
  });

  test('chỉ đổi sort_order -> không có dòng chi tiết', () {
    final result = _describe(
      _entry(
        entityType: 'branch',
        before: {'name': 'Chi Nhất', 'sort_order': 0},
        after: {'name': 'Chi Nhất', 'sort_order': 2},
      ),
    );
    expect(result.title, 'Sửa chi: Chi Nhất');
    expect(result.details, isEmpty);
  });

  test('xóa chi (xóa thật, after = null)', () {
    final result = _describe(
      _entry(
        entityType: 'branch',
        action: 'delete',
        before: {'name': 'Chi Nhất', 'parent_branch_id': null},
      ),
    );
    expect(result.title, 'Xóa chi: Chi Nhất');
    expect(result.details, ['Chi này đã bị xóa khỏi gia phả.']);
  });

  test('sửa thông tin dòng họ: các dòng "cũ → mới"', () {
    final result = _describe(
      _entry(
        entityType: 'clan_info',
        entityId: '00000000-0000-0000-0000-000000000001',
        before: {'name': 'Họ Nguyễn', 'origin': null, 'description': 'Cũ'},
        after: {
          'name': 'Họ Nguyễn Văn',
          'origin': 'Gốc Thanh Hóa',
          'description': 'Cũ',
        },
      ),
    );
    expect(result.title, 'Sửa thông tin dòng họ');
    expect(result.details, [
      'Tên dòng họ: Họ Nguyễn → Họ Nguyễn Văn',
      'Nguồn gốc: (trống) → Gốc Thanh Hóa',
    ]);
  });

  test('sửa thông tin dòng họ: xóa trống một ô', () {
    final result = _describe(
      _entry(
        entityType: 'clan_info',
        before: {'name': 'Họ Nguyễn', 'origin': 'Gốc Thanh Hóa'},
        after: {'name': 'Họ Nguyễn', 'origin': null},
      ),
    );
    expect(result.details, ['Nguồn gốc: Gốc Thanh Hóa → (trống)']);
  });

  test('buildHistoryBranches: chi trong cây ưu tiên, chi đã xóa lấy từ lịch sử',
      () {
    final merged = buildHistoryBranches(
      tree: _treeOf(const [_chiNhat]),
      entries: [
        _entry(
          entityType: 'branch',
          action: 'delete',
          entityId: 'gone',
          before: {'name': 'Nhánh Cũ', 'parent_branch_id': 'gone2'},
        ),
        _entry(
          entityType: 'branch',
          action: 'delete',
          entityId: 'gone2',
          before: {'name': 'Chi Đã Xóa', 'parent_branch_id': null},
        ),
        _entry(
          entityType: 'branch',
          entityId: 'b1',
          before: {'name': 'Tên Cũ', 'parent_branch_id': null},
          after: {'name': 'Tên Cũ Nữa', 'parent_branch_id': null},
        ),
      ],
    );
    expect(merged, hasLength(3));
    expect(branchPathOf('b1', merged), 'Chi Nhất');
    expect(branchPathOf('gone', merged), 'Chi Đã Xóa › Nhánh Cũ');

    final same = buildHistoryBranches(
      tree: _treeOf(const [_chiNhat]),
      entries: [_entry(before: {'full_name': 'Không phải chi'})],
    );
    expect(same, hasLength(1));
  });

  test('sửa người: chi cũ đã xóa vẫn hiện tên nhờ danh sách chi gộp', () {
    final merged = buildHistoryBranches(
      tree: _treeOf(const [_chiNhat]),
      entries: [
        _entry(
          entityType: 'branch',
          action: 'delete',
          entityId: 'gone',
          before: {'name': 'Chi Đã Xóa', 'parent_branch_id': null},
        ),
      ],
    );
    final result = _describeWith(
      _entry(
        before: {'full_name': 'Nguyễn Văn A', 'branch_id': 'gone'},
        after: {'full_name': 'Nguyễn Văn A', 'branch_id': 'b1'},
      ),
      merged,
    );
    expect(result.details, ['Chi/nhánh: Chi Đã Xóa → Chi Nhất']);
  });
}