import 'package:flutter_test/flutter_test.dart';

import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/person/domain/person_create.dart';
import 'package:familytree/features/person/domain/relation_changes.dart';
import 'package:familytree/features/proposals/domain/request_draft.dart';
import 'package:familytree/features/tree/domain/marriage.dart';
import 'package:familytree/features/tree/domain/parent_child.dart';

const int _now = 2026;

Person _p(String id) {
  return Person(
    id: id,
    fullName: 'N $id',
    gender: Gender.male,
    isAlive: true,
    memorialIsLeap: false,
  );
}

ParentChild _pc(
  String id,
  String parent,
  String child, [
  RelationType type = RelationType.biological,
]) {
  return ParentChild(
    id: id,
    parentId: parent,
    childId: child,
    relationType: type,
  );
}

Marriage _m({
  String id = 'm1',
  String p1 = 'a',
  String p2 = 'b',
  MarriageStatus status = MarriageStatus.married,
  DateTime? start,
  DateTime? end,
  String? notes,
}) {
  return Marriage(
    id: id,
    person1Id: p1,
    person2Id: p2,
    status: status,
    startDate: start,
    endDate: end,
    notes: notes,
  );
}

Map<String, dynamic> _update(
  Marriage original,
  MarriageFormValues values, {
  String notes = '',
}) {
  return buildMarriageUpdatePayload(
    original,
    values,
    notes: notes,
    nowYear: _now,
  );
}

void main() {
  group('validateReason', () {
    test('bắt buộc mà để trống là lỗi', () {
      expect(validateReason('   ', required: true), isNotNull);
    });

    test('bắt buộc mà chỉ 2 ký tự là lỗi', () {
      expect(validateReason('ab', required: true), isNotNull);
    });

    test('bắt buộc, đủ 3 ký tự thì hợp lệ', () {
      expect(validateReason('abc', required: true), isNull);
    });

    test('không bắt buộc, để trống thì hợp lệ', () {
      expect(validateReason('', required: false), isNull);
    });

    test('quá dài là lỗi', () {
      expect(validateReason('a' * 501, required: false), isNotNull);
    });
  });

  group('planChangeRelationType', () {
    test('đổi cả hai dòng của đứa trẻ', () {
      final drafts = planChangeRelationType(
        childId: 'c',
        parentChildren: [_pc('r1', 'a', 'c'), _pc('r2', 'b', 'c')],
        newType: RelationType.adopted,
      );
      expect(drafts.map((d) => d.entityId).toList(), ['r1', 'r2']);
      expect(drafts.every((d) => d.action == kActionUpdate), isTrue);
      expect(drafts.first.payload, {'relation_type': 'adopted'});
    });

    test('bỏ qua dòng đã đúng loại', () {
      final drafts = planChangeRelationType(
        childId: 'c',
        parentChildren: [
          _pc('r1', 'a', 'c', RelationType.adopted),
          _pc('r2', 'b', 'c'),
        ],
        newType: RelationType.adopted,
      );
      expect(drafts.map((d) => d.entityId).toList(), ['r2']);
    });

    test('không có gì cần đổi thì rỗng', () {
      final drafts = planChangeRelationType(
        childId: 'c',
        parentChildren: [_pc('r1', 'a', 'c')],
        newType: RelationType.biological,
      );
      expect(drafts, isEmpty);
    });

    test('không đụng dòng của đứa trẻ khác', () {
      final drafts = planChangeRelationType(
        childId: 'c',
        parentChildren: [_pc('r1', 'a', 'c'), _pc('r9', 'a', 'khac')],
        newType: RelationType.step,
      );
      expect(drafts.map((d) => d.entityId).toList(), ['r1']);
    });
  });

  group('gỡ quan hệ', () {
    test('gỡ một dòng cha-con', () {
      final drafts = planRemoveParentChild(_pc('r1', 'a', 'c'));
      expect(drafts.length, 1);
      expect(drafts.first.entityType, kEntityParentChild);
      expect(drafts.first.action, kActionDelete);
      expect(drafts.first.entityId, 'r1');
      expect(drafts.first.payload, isEmpty);
    });

    test('gỡ một hôn nhân', () {
      final drafts = planRemoveMarriage(_m(id: 'm7'));
      expect(drafts.length, 1);
      expect(drafts.first.entityType, kEntityMarriage);
      expect(drafts.first.action, kActionDelete);
      expect(drafts.first.entityId, 'm7');
    });
  });

  group('planDeletePerson', () {
    final links = [
      _pc('pc1', 'p1', 'x'),
      _pc('pc2', 'p2', 'x'),
      _pc('pc3', 'p1', 'y'),
    ];
    final marriages = [
      _m(id: 'm1', p1: 'x', p2: 's'),
      _m(id: 'm2', p1: 'a', p2: 'b'),
    ];

    test('thứ tự: cha mẹ, hôn nhân, rồi người', () {
      final drafts = planDeletePerson(
        person: _p('x'),
        parentChildren: links,
        marriages: marriages,
      );
      expect(
        drafts.map((d) => d.entityType).toList(),
        [kEntityParentChild, kEntityParentChild, kEntityMarriage, kEntityPerson],
      );
      expect(
        drafts.map((d) => d.entityId).toList(),
        ['pc1', 'pc2', 'm1', 'x'],
      );
      expect(drafts.every((d) => d.action == kActionDelete), isTrue);
    });

    test('không xóa quan hệ của người khác', () {
      final ids = planDeletePerson(
        person: _p('x'),
        parentChildren: links,
        marriages: marriages,
      ).map((d) => d.entityId).toList();
      expect(ids.contains('pc3'), isFalse);
      expect(ids.contains('m2'), isFalse);
    });

    test('người không có quan hệ chỉ có một dòng xóa người', () {
      final drafts = planDeletePerson(
        person: _p('z'),
        parentChildren: const [],
        marriages: const [],
      );
      expect(drafts.length, 1);
      expect(drafts.first.entityType, kEntityPerson);
    });

    test('còn con thì ném ArgumentError', () {
      expect(
        () => planDeletePerson(
          person: _p('p1'),
          parentChildren: links,
          marriages: marriages,
        ),
        throwsArgumentError,
      );
    });

    test('personHasChildren', () {
      expect(personHasChildren('p1', links), isTrue);
      expect(personHasChildren('x', links), isFalse);
    });
  });

  group('buildMarriageUpdatePayload', () {
    test('không đổi gì thì payload rỗng', () {
      final original = _m(
        status: MarriageStatus.divorced,
        start: DateTime(1972, 6, 1),
        end: DateTime(1984, 4, 3),
        notes: 'ghi chú',
      );
      final values = marriageFormValuesOf(original);
      expect(_update(original, values, notes: 'ghi chú'), isEmpty);
    });

    test('đổi sang ly hôn, thêm năm kết thúc', () {
      final original = _m(start: DateTime(1978));
      final values = marriageFormValuesOf(original)
        ..status = MarriageStatus.divorced
        ..endYear = '1990';
      expect(_update(original, values), {
        'status': 'divorced',
        'end_date': '1990-01-01',
      });
    });

    test('đổi về đang kết hôn thì xóa ngày kết thúc (null)', () {
      final original = _m(
        status: MarriageStatus.divorced,
        start: DateTime(1972),
        end: DateTime(1984, 4, 3),
      );
      final values = marriageFormValuesOf(original)
        ..status = MarriageStatus.married;
      expect(_update(original, values), {
        'status': 'married',
        'end_date': null,
      });
    });

    test('đổi ghi chú', () {
      final original = _m();
      final values = marriageFormValuesOf(original);
      expect(_update(original, values, notes: 'ghi chú mới'), {
        'notes': 'ghi chú mới',
      });
    });

    test('xóa ghi chú thì gửi null', () {
      final original = _m(notes: 'cũ');
      final values = marriageFormValuesOf(original);
      expect(_update(original, values), {'notes': null});
    });

    test('đổi ngày bắt đầu', () {
      final original = _m(start: DateTime(1978));
      final values = marriageFormValuesOf(original)..startYear = '1979';
      expect(_update(original, values), {'start_date': '1979-01-01'});
    });

    test('dữ liệu sai thì ném ArgumentError', () {
      final original = _m();
      final values = marriageFormValuesOf(original)
        ..startDay = '31'
        ..startMonth = '2'
        ..startYear = '1950';
      expect(() => _update(original, values), throwsArgumentError);
    });
  });

  group('marriageFormValuesOf', () {
    test('tách ngày tháng năm', () {
      final values = marriageFormValuesOf(
        _m(
          status: MarriageStatus.divorced,
          start: DateTime(1972, 6, 1),
          end: DateTime(1984, 4, 3),
        ),
      );
      expect(values.status, MarriageStatus.divorced);
      expect(
        [
          values.startDay,
          values.startMonth,
          values.startYear,
          values.endDay,
          values.endMonth,
          values.endYear,
        ],
        ['1', '6', '1972', '3', '4', '1984'],
      );
    });

    test('không có ngày thì các ô rỗng', () {
      final values = marriageFormValuesOf(_m());
      expect(values.startYear, isEmpty);
      expect(values.endYear, isEmpty);
    });
  });
}