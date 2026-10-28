import 'package:flutter_test/flutter_test.dart';
import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/review/domain/change_request.dart';
import 'package:familytree/features/review/domain/request_describer.dart';
import 'package:familytree/features/tree/domain/tree_data.dart';

const String _t0 = '2026-10-28T03:00:00.123456+00:00';
const String _toId = 'a0000000-0000-0000-0000-000000000001';

TreeData _tree() {
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
      }),
    ],
    branches: const [],
    parentChildren: const [],
    marriages: const [],
    photos: const [],
  );
}

ChangeRequest _photoRequest(String personId) {
  return ChangeRequest(
    id: 'r1',
    requesterId: 'u1',
    nickname: 'Bác Hai',
    entityType: 'person_photo',
    action: 'create',
    payload: {
      'id': 'f1',
      'person_id': personId,
      'storage_path': '$personId/f1.jpg',
      'caption': 'Ảnh Tết',
      'is_avatar': false,
      'sort_order': 0,
    },
    status: 'pending',
    createdAtRaw: _t0,
    createdAt: DateTime.parse(_t0),
  );
}

void main() {
  test('đề xuất thêm ảnh: tiêu đề, mô tả và đường dẫn xem trước', () {
    final bundle = groupRequests([_photoRequest(_toId)]).single;
    final result = describeBundle(bundle, _tree()).single;
    expect(result.title, 'Thêm ảnh cho Nguyễn Văn Tổ');
    expect(result.details, ['Mô tả: Ảnh Tết']);
    expect(result.supported, isTrue);
    expect(result.warning, isNull);
    expect(result.photo?.pendingPath, 'u1/f1.jpg');
    expect(result.photo?.publicPath, '$_toId/f1.jpg');
  });

  test('đề xuất thêm ảnh cho người không còn trong cây -> có cảnh báo', () {
    final bundle = groupRequests([_photoRequest('khong-co')]).single;
    final result = describeBundle(bundle, _tree()).single;
    expect(result.warning, isNotNull);
  });

  test('ảnh là loại được duyệt (hasUnsupported = false)', () {
    final bundle = groupRequests([_photoRequest(_toId)]).single;
    expect(bundle.hasUnsupported, isFalse);
  });
}