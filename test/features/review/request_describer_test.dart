import 'package:flutter_test/flutter_test.dart';
import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/review/domain/change_request.dart';
import 'package:familytree/features/review/domain/request_describer.dart';
import 'package:familytree/features/tree/domain/tree_data.dart';

const String _t0 = '2026-10-28T03:00:00.123456+00:00';
const String _toId = 'a0000000-0000-0000-0000-000000000001';

Person _person({String? birthPlace}) {
  return Person.fromJson({
    'id': _toId,
    'full_name': 'Nguyễn Văn Tổ',
    'other_name': null,
    'gender': 'male',
    'branch_id': null,
    'generation': 1,
    'birth_date': null,
    'birth_year': null,
    'birth_place': birthPlace,
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

TreeData _tree({String? birthPlace}) {
  return TreeData(
    people: [_person(birthPlace: birthPlace)],
    branches: const [],
    parentChildren: const [],
    marriages: const [],
    photos: const [],
  );
}

ChangeRequest _req({
  String id = 'r1',
  String entityType = 'person',
  String action = 'create',
  String? entityId,
  Map<String, dynamic> payload = const {},
}) {
  return ChangeRequest(
    id: id,
    requesterId: 'u1',
    nickname: 'Bác Hai',
    entityType: entityType,
    entityId: entityId,
    action: action,
    payload: payload,
    status: 'pending',
    createdAtRaw: _t0,
    createdAt: DateTime.parse(_t0),
  );
}

List<DescribedRequest> _describe(List<ChangeRequest> requests, TreeData tree) {
  return describeBundle(groupRequests(requests).single, tree);
}

void main() {
  test('thêm người: tiêu đề và các dòng chi tiết', () {
    final result = _describe(
      [
        _req(payload: {
          'id': 'n1',
          'full_name': 'Nguyễn Văn B',
          'gender': 'male',
          'birth_year': 1990,
        }),
      ],
      _tree(),
    );
    expect(result.single.title, 'Thêm người: Nguyễn Văn B');
    expect(result.single.details, contains('Giới tính: Nam'));
    expect(result.single.details, contains('Năm sinh: 1990'));
  });

  test('sửa người: liệt kê "cũ → mới"', () {
    final result = _describe(
      [
        _req(
          action: 'update',
          entityId: _toId,
          payload: {'birth_place': 'Đà Nẵng'},
        ),
      ],
      _tree(birthPlace: 'Huế'),
    );
    expect(result.single.title, 'Sửa thông tin: Nguyễn Văn Tổ');
    expect(result.single.details, ['Nơi sinh: Huế → Đà Nẵng']);
    expect(result.single.warning, isNull);
  });

  test('sửa người: bỏ qua dòng có giá trị không đổi', () {
    final result = _describe(
      [
        _req(
          action: 'update',
          entityId: _toId,
          payload: {'birth_place': 'Huế'},
        ),
      ],
      _tree(birthPlace: 'Huế'),
    );
    expect(result.single.details, isEmpty);
  });

  test('xóa người không còn trong cây -> có cảnh báo', () {
    final result = _describe(
      [_req(action: 'delete', entityId: 'khong-co')],
      _tree(),
    );
    expect(result.single.title, 'Xóa người: (người không còn trong gia phả)');
    expect(result.single.warning, isNotNull);
  });

  test('chi/nhánh -> app chưa hỗ trợ', () {
    final result = _describe([_req(entityType: 'branch')], _tree());
    expect(result.single.supported, isFalse);
  });

  test('gắn cha-con: dùng tên người MỚI trong cùng gói', () {
    final result = _describe(
      [
        _req(
          id: 'p',
          payload: {'id': 'n1', 'full_name': 'Nguyễn Văn B', 'gender': 'male'},
        ),
        _req(
          id: 'pc',
          entityType: 'parent_child',
          payload: {
            'parent_id': _toId,
            'child_id': 'n1',
            'relation_type': 'biological',
          },
        ),
      ],
      _tree(),
    );
    expect(
      result[1].title,
      'Gắn Nguyễn Văn B là con ruột của Nguyễn Văn Tổ',
    );
    expect(result[1].warning, isNull);
  });

  test('gắn cha-con: người không tồn tại -> có cảnh báo', () {
    final result = _describe(
      [
        _req(
          entityType: 'parent_child',
          payload: {
            'parent_id': 'zzz',
            'child_id': _toId,
            'relation_type': 'adopted',
          },
        ),
      ],
      _tree(),
    );
    expect(result.single.warning, isNotNull);
  });
}
