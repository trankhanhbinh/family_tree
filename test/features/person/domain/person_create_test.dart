import 'package:flutter_test/flutter_test.dart';

import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/person/domain/person_create.dart';
import 'package:familytree/features/person/domain/person_edit_form.dart';
import 'package:familytree/features/proposals/domain/request_draft.dart';
import 'package:familytree/features/tree/domain/marriage.dart';
import 'package:familytree/features/tree/domain/parent_child.dart';

const int _now = 2026;

Person _person({
  String id = 'x',
  Gender gender = Gender.male,
  int? generation = 2,
}) {
  return Person(
    id: id,
    fullName: 'Nguyễn Văn Nhì',
    gender: gender,
    generation: generation,
    isAlive: true,
    memorialIsLeap: false,
  );
}

PersonFormValues _v([Gender gender = Gender.male]) {
  return PersonFormValues(fullName: 'Nguyễn Văn A', gender: gender);
}

Map<String, dynamic> _create(PersonFormValues v, {int? generation}) {
  return buildPersonCreatePayload(
    v,
    id: 'n1',
    generation: generation,
    nowYear: _now,
  );
}

void main() {
  group('buildPersonCreatePayload', () {
    test('tối thiểu', () {
      expect(_create(_v()), {
        'id': 'n1',
        'full_name': 'Nguyễn Văn A',
        'gender': 'male',
        'is_alive': true,
      });
    });

    test('có số đời', () {
      expect(_create(_v(), generation: 3)['generation'], 3);
    });

    test('không có số đời thì không có khóa generation', () {
      expect(_create(_v()).containsKey('generation'), isFalse);
    });

    test('người còn sống đủ thông tin', () {
      final v = _v(Gender.female)
        ..otherName = 'Tí'
        ..branchId = 'b1'
        ..birthDay = '5'
        ..birthMonth = '3'
        ..birthYear = '1950'
        ..birthPlace = 'Huế'
        ..notes = 'ghi chú';
      expect(_create(v), {
        'id': 'n1',
        'full_name': 'Nguyễn Văn A',
        'gender': 'female',
        'other_name': 'Tí',
        'branch_id': 'b1',
        'birth_date': '1950-03-05',
        'birth_year': 1950,
        'birth_place': 'Huế',
        'is_alive': true,
        'notes': 'ghi chú',
      });
    });

    test('chỉ nhập năm sinh', () {
      final payload = _create(_v()..birthYear = '1950');
      expect(payload['birth_year'], 1950);
      expect(payload.containsKey('birth_date'), isFalse);
    });

    test('người đã mất', () {
      final v = _v()
        ..birthYear = '1950'
        ..isAlive = false
        ..deathDay = '1'
        ..deathMonth = '6'
        ..deathYear = '2019'
        ..burialPlace = 'Huế'
        ..memorialDay = '15'
        ..memorialMonth = '7'
        ..memorialIsLeap = true;
      expect(_create(v), {
        'id': 'n1',
        'full_name': 'Nguyễn Văn A',
        'gender': 'male',
        'birth_year': 1950,
        'is_alive': false,
        'death_date': '2019-06-01',
        'death_year': 2019,
        'burial_place': 'Huế',
        'memorial_lunar_day': 15,
        'memorial_lunar_month': 7,
        'memorial_is_leap': true,
      });
    });

    test('còn sống thì bỏ qua dữ liệu mất/giỗ nhập dở', () {
      final v = _v()
        ..deathYear = '1999'
        ..memorialDay = '15'
        ..memorialMonth = '7';
      final payload = _create(v);
      expect(payload.containsKey('death_year'), isFalse);
      expect(payload.containsKey('memorial_lunar_day'), isFalse);
    });

    test('đã mất nhưng không nhập giỗ thì không có khóa giỗ', () {
      final payload = _create(_v()..isAlive = false);
      expect(payload.containsKey('memorial_lunar_day'), isFalse);
      expect(payload.containsKey('memorial_is_leap'), isFalse);
    });

    test('không có giá trị null nào', () {
      final v = _v()
        ..otherName = 'Tí'
        ..birthYear = '1950'
        ..isAlive = false
        ..deathYear = '2019';
      final payload = _create(v, generation: 3);
      expect(payload.values.every((value) => value != null), isTrue);
    });

    test('họ tên rỗng thì ném ArgumentError', () {
      final v = PersonFormValues(fullName: '  ');
      expect(() => _create(v), throwsArgumentError);
    });

    test('khoảng trắng thừa trong họ tên được gộp', () {
      final v = PersonFormValues(fullName: '  Nguyễn   Văn A ');
      expect(_create(v)['full_name'], 'Nguyễn Văn A');
    });
  });

  group('planAddChild', () {
    List<RequestDraft> plan({
      Person? other,
      RelationType relation = RelationType.biological,
      Person? parent,
    }) {
      return planAddChild(
        values: _v(),
        childId: 'c1',
        parent: parent ?? _person(),
        otherParent: other,
        relation: relation,
        nowYear: _now,
      );
    }

    test('cha và mẹ: 3 dòng theo thứ tự người, cha-con, cha-con', () {
      final drafts = plan(other: _person(id: 'y', gender: Gender.female));
      expect(
        drafts.map((d) => d.entityType).toList(),
        [kEntityPerson, kEntityParentChild, kEntityParentChild],
      );
      expect(drafts.every((d) => d.action == kActionCreate), isTrue);
    });

    test('payload cha-con', () {
      final drafts = plan(other: _person(id: 'y', gender: Gender.female));
      expect(drafts[1].payload, {
        'parent_id': 'x',
        'child_id': 'c1',
        'relation_type': 'biological',
      });
      expect(drafts[2].payload['parent_id'], 'y');
    });

    test('chỉ một phụ huynh: 2 dòng', () {
      expect(plan().length, 2);
    });

    test('số đời của con = đời của cha/mẹ + 1', () {
      expect(plan().first.payload['generation'], 3);
    });

    test('cha/mẹ chưa có số đời thì không gửi generation', () {
      final drafts = plan(parent: _person(generation: null));
      expect(drafts.first.payload.containsKey('generation'), isFalse);
    });

    test('con nuôi áp dụng cho mọi dòng cha-con', () {
      final drafts = plan(
        other: _person(id: 'y', gender: Gender.female),
        relation: RelationType.adopted,
      );
      expect(drafts[1].payload['relation_type'], 'adopted');
      expect(drafts[2].payload['relation_type'], 'adopted');
    });

    test('dòng người mới không có entityId', () {
      expect(plan().first.entityId, isNull);
    });
  });

  group('planAddSpouse', () {
    List<RequestDraft> plan({
      Person? partner,
      Gender spouseGender = Gender.female,
      MarriageFormValues? marriage,
    }) {
      return planAddSpouse(
        values: _v(spouseGender),
        spouseId: 's1',
        partner: partner ?? _person(),
        marriage: marriage ?? MarriageFormValues(),
        nowYear: _now,
      );
    }

    test('2 dòng: người rồi hôn nhân', () {
      final drafts = plan();
      expect(
        drafts.map((d) => d.entityType).toList(),
        [kEntityPerson, kEntityMarriage],
      );
    });

    test('số đời của vợ/chồng bằng của bạn đời', () {
      expect(plan().first.payload['generation'], 2);
    });

    test('chồng có sẵn, vợ mới: chồng là person1', () {
      final payload = plan().last.payload;
      expect(payload['person1_id'], 'x');
      expect(payload['person2_id'], 's1');
    });

    test('vợ có sẵn, chồng mới: người mới là person1', () {
      final payload = plan(
        partner: _person(gender: Gender.female),
        spouseGender: Gender.male,
      ).last.payload;
      expect(payload['person1_id'], 's1');
      expect(payload['person2_id'], 'x');
    });

    test('cùng giới nam: người có sẵn là person1', () {
      final payload = plan(spouseGender: Gender.male).last.payload;
      expect(payload['person1_id'], 'x');
    });

    test('không ai là nam: người có sẵn là person1', () {
      final payload = plan(
        partner: _person(gender: Gender.female),
      ).last.payload;
      expect(payload['person1_id'], 'x');
    });

    test('chỉ nhập năm bắt đầu thì lưu 1/1', () {
      final payload = plan(
        marriage: MarriageFormValues(startYear: '1978'),
      ).last.payload;
      expect(payload, {
        'person1_id': 'x',
        'person2_id': 's1',
        'status': 'married',
        'start_date': '1978-01-01',
      });
    });

    test('đã ly hôn: có cả ngày kết thúc', () {
      final payload = plan(
        marriage: MarriageFormValues(
          status: MarriageStatus.divorced,
          startYear: '1972',
          endDay: '3',
          endMonth: '4',
          endYear: '1984',
        ),
      ).last.payload;
      expect(payload['status'], 'divorced');
      expect(payload['start_date'], '1972-01-01');
      expect(payload['end_date'], '1984-04-03');
    });

    test('đang kết hôn thì bỏ qua ngày kết thúc nhập dở', () {
      final payload = plan(
        marriage: MarriageFormValues(endYear: '2000'),
      ).last.payload;
      expect(payload.containsKey('end_date'), isFalse);
    });

    test('không nhập ngày thì không có khóa ngày', () {
      final payload = plan().last.payload;
      expect(payload.containsKey('start_date'), isFalse);
      expect(payload.containsKey('end_date'), isFalse);
    });

    test('dữ liệu hôn nhân sai thì ném ArgumentError', () {
      expect(
        () => plan(
          marriage: MarriageFormValues(
            startDay: '31',
            startMonth: '2',
            startYear: '1950',
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  group('validateMarriageForm', () {
    Map<MarriageField, String> check(MarriageFormValues v) {
      return validateMarriageForm(v, nowYear: _now);
    }

    test('mặc định hợp lệ', () {
      expect(check(MarriageFormValues()), isEmpty);
    });

    test('ngày bắt đầu 31/2 là lỗi', () {
      final v = MarriageFormValues(
        startDay: '31',
        startMonth: '2',
        startYear: '1950',
      );
      expect(check(v)[MarriageField.start], isNotNull);
    });

    test('năm kết thúc nhỏ hơn năm bắt đầu', () {
      final v = MarriageFormValues(
        status: MarriageStatus.divorced,
        startYear: '1984',
        endYear: '1972',
      );
      expect(check(v)[MarriageField.end], isNotNull);
    });

    test('cùng năm, bắt đầu đủ ngày, kết thúc chỉ năm: không lỗi', () {
      final v = MarriageFormValues(
        status: MarriageStatus.divorced,
        startDay: '1',
        startMonth: '6',
        startYear: '1980',
        endYear: '1980',
      );
      expect(check(v), isEmpty);
    });

    test('đang kết hôn thì không kiểm tra ngày kết thúc', () {
      expect(check(MarriageFormValues(endYear: 'abc')), isEmpty);
    });

    test('năm bắt đầu ở tương lai là lỗi', () {
      expect(
        check(MarriageFormValues(startYear: '2027'))[MarriageField.start],
        isNotNull,
      );
    });

    test('ngày kết thúc thiếu tháng là lỗi', () {
      final v = MarriageFormValues(
        status: MarriageStatus.widowed,
        endDay: '5',
        endYear: '1990',
      );
      expect(check(v)[MarriageField.end], isNotNull);
    });
  });

  group('giới tính bắt buộc chọn', () {
    test('chưa chọn thì báo lỗi', () {
      final errors = validatePersonForm(
        PersonFormValues(fullName: 'Nguyễn Văn A'),
        nowYear: _now,
        genderChosen: false,
      );
      expect(errors[PersonField.gender], isNotNull);
    });

    test('mặc định (đã chọn) thì không lỗi giới tính', () {
      final errors = validatePersonForm(
        PersonFormValues(fullName: 'Nguyễn Văn A'),
        nowYear: _now,
      );
      expect(errors.containsKey(PersonField.gender), isFalse);
    });
  });
}