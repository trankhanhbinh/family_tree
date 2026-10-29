import 'package:flutter_test/flutter_test.dart';
import 'package:familytree/features/history/domain/deleted_person.dart';
import 'package:familytree/features/history/domain/restore_result.dart';

String? _names(Object? id) {
  return switch (id) {
    'c1' => 'Nguyễn Thị B',
    'p1' => 'Nguyễn Văn A',
    _ => null,
  };
}

RestoreResult _result({
  bool hadHistory = true,
  int restored = 0,
  List<Map<String, dynamic>> skipped = const [],
}) {
  return RestoreResult.fromJson({
    'person_id': 'a1',
    'person_name': 'Bà A',
    'had_history': hadHistory,
    'restored_relations': restored,
    'skipped': skipped,
  });
}

void main() {
  test('DeletedPerson.fromJson: đọc đủ trường', () {
    final person = DeletedPerson.fromJson({
      'id': 'a1',
      'full_name': 'Nguyễn Thị An',
      'birth_year': 2010,
      'death_year': null,
      'deleted_at': '2026-10-27T20:43:39.640461+00:00',
    });
    expect(person.id, 'a1');
    expect(person.fullName, 'Nguyễn Thị An');
    expect(person.birthYear, 2010);
    expect(person.deathYear, isNull);
    expect(person.deletedAt, DateTime.parse('2026-10-27T20:43:39.640461+00:00'));
  });

  test('lifeSpan: có cả năm sinh và năm mất', () {
    final person = DeletedPerson(
      id: 'a1',
      fullName: 'A',
      birthYear: 1950,
      deathYear: 2010,
      deletedAt: DateTime(2026),
    );
    expect(person.lifeSpan, 'Sinh 1950, mất 2010');
  });

  test('lifeSpan: chỉ có năm sinh', () {
    final person = DeletedPerson(
      id: 'a1',
      fullName: 'A',
      birthYear: 2010,
      deletedAt: DateTime(2026),
    );
    expect(person.lifeSpan, 'Sinh 2010');
  });

  test('lifeSpan: không có năm nào', () {
    final person = DeletedPerson(
      id: 'a1',
      fullName: 'A',
      deletedAt: DateTime(2026),
    );
    expect(person.lifeSpan, 'Chưa rõ năm sinh, năm mất');
  });

  test('RestoreResult.fromJson: đọc số quan hệ và danh sách bỏ qua', () {
    final result = _result(
      restored: 2,
      skipped: [
        {
          'entity_type': 'parent_child',
          'entity_id': 'x1',
          'reason': 'PERSON_MISSING',
          'other_person_id': 'c1',
          'person_is': 'parent',
        },
      ],
    );
    expect(result.personId, 'a1');
    expect(result.personName, 'Bà A');
    expect(result.hadHistory, isTrue);
    expect(result.restoredRelations, 2);
    expect(result.skipped, hasLength(1));
    expect(result.skipped.single.reason, 'PERSON_MISSING');
    expect(result.skipped.single.otherPersonId, 'c1');
    expect(result.skipped.single.personIs, 'parent');
  });

  test('mô tả: dựng lại đủ, không bỏ qua cái nào', () {
    expect(
      describeRestoreResult(_result(restored: 2), _names),
      'Đã đưa Bà A trở lại gia phả.\nĐã dựng lại 2 quan hệ.',
    );
  });

  test('mô tả: không có lịch sử lần xóa', () {
    expect(
      describeRestoreResult(_result(hadHistory: false), _names),
      'Đã đưa Bà A trở lại gia phả.\n'
      'Không tìm thấy lịch sử lần xóa, nên chưa dựng lại quan hệ nào. '
      'Hãy thêm lại quan hệ bằng các nút trên hồ sơ.',
    );
  });

  test('mô tả: lúc xóa không có quan hệ nào bị gỡ', () {
    expect(
      describeRestoreResult(_result(), _names),
      'Đã đưa Bà A trở lại gia phả.\n'
      'Lúc xóa, người này không có quan hệ nào bị gỡ.',
    );
  });

  test('mô tả: liệt kê quan hệ bị bỏ qua kèm tên và lý do', () {
    final result = _result(
      restored: 1,
      skipped: [
        {
          'entity_type': 'parent_child',
          'entity_id': 'x1',
          'reason': 'PERSON_MISSING',
          'other_person_id': 'c1',
          'person_is': 'parent',
        },
        {
          'entity_type': 'marriage',
          'entity_id': 'x2',
          'reason': 'ALREADY_EXISTS',
          'other_person_id': 'p1',
        },
        {
          'entity_type': 'parent_child',
          'entity_id': 'x3',
          'reason': 'CYCLE_DETECTED',
          'other_person_id': 'zz',
          'person_is': 'child',
        },
      ],
    );
    expect(
      describeRestoreResult(result, _names),
      [
        'Đã đưa Bà A trở lại gia phả.',
        'Đã dựng lại 1 quan hệ.',
        '',
        'Bỏ qua 3 quan hệ:',
        '• Con Nguyễn Thị B: người này đã bị xóa',
        '• Vợ/chồng Nguyễn Văn A: quan hệ này đã có rồi',
        '• Cha/mẹ (không rõ): sẽ làm một người thành tổ tiên của chính mình',
        '',
        'Có thể thêm lại các quan hệ này bằng các nút trên hồ sơ.',
      ].join('\n'),
    );
  });
}