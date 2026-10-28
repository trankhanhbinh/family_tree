import 'package:flutter_test/flutter_test.dart';
import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/review/domain/change_request.dart';
import 'package:familytree/features/review/domain/request_describer.dart';
import 'package:familytree/features/tree/domain/tree_data.dart';

const String _t0 = '2026-10-28T03:00:00.123456+00:00';
const String _toId = 'a0000000-0000-0000-0000-000000000001';

TreeData _tree({String? birthPlace}) {
  return TreeData(
    people: [
      Person.fromJson({
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
      }),
    ],
    branches: const [],
    parentChildren: const [],
    marriages: const [],
    photos: const [],
  );
}

DescribedRequest _describeOne({
  required String status,
  required String action,
  String? entityId,
  Map<String, dynamic> payload = const {},
  required TreeData tree,
}) {
  final request = ChangeRequest(
    id: 'r1',
    requesterId: 'u1',
    nickname: 'Bác Hai',
    entityType: 'person',
    entityId: entityId,
    action: action,
    payload: payload,
    status: status,
    createdAtRaw: _t0,
    createdAt: DateTime.parse(_t0),
  );
  return describeBundle(groupRequests([request]).single, tree).single;
}

void main() {
  test('đã duyệt: sửa người chỉ hiện giá trị mới (cây đã được cập nhật)', () {
    final result = _describeOne(
      status: 'approved',
      action: 'update',
      entityId: _toId,
      payload: {'birth_place': 'Đà Nẵng'},
      tree: _tree(birthPlace: 'Đà Nẵng'),
    );
    expect(result.details, ['Nơi sinh: Đà Nẵng']);
    expect(result.warning, isNull);
  });

  test('đã duyệt: xóa người không còn trong cây -> tiêu đề chung, không cảnh báo',
      () {
    final result = _describeOne(
      status: 'approved',
      action: 'delete',
      entityId: 'khong-co',
      tree: _tree(),
    );
    expect(result.title, 'Xóa một người khỏi gia phả');
    expect(result.warning, isNull);
  });

  test('bị từ chối: sửa người vẫn so "cũ → mới" (cây không đổi)', () {
    final result = _describeOne(
      status: 'rejected',
      action: 'update',
      entityId: _toId,
      payload: {'birth_place': 'Đà Nẵng'},
      tree: _tree(birthPlace: 'Huế'),
    );
    expect(result.details, ['Nơi sinh: Huế → Đà Nẵng']);
  });

  test('bị từ chối: mục không còn trong cây -> không cảnh báo', () {
    final result = _describeOne(
      status: 'rejected',
      action: 'delete',
      entityId: 'khong-co',
      tree: _tree(),
    );
    expect(result.title, 'Xóa một người khỏi gia phả');
    expect(result.warning, isNull);
  });
}