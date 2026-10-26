import 'package:flutter_test/flutter_test.dart';

import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/person/domain/person_edit_form.dart';

const int _now = 2026;

Person _person({
  String fullName = 'Nguyễn Văn Nhì',
  String? otherName,
  Gender gender = Gender.male,
  String? branchId,
  DateTime? birthDate,
  int? birthYear,
  String? birthPlace,
  bool isAlive = true,
  DateTime? deathDate,
  int? deathYear,
  String? burialPlace,
  int? memorialLunarDay,
  int? memorialLunarMonth,
  bool memorialIsLeap = false,
  String? notes,
}) {
  return Person(
    id: 'p1',
    fullName: fullName,
    otherName: otherName,
    gender: gender,
    branchId: branchId,
    birthDate: birthDate,
    birthYear: birthYear,
    birthPlace: birthPlace,
    isAlive: isAlive,
    deathDate: deathDate,
    deathYear: deathYear,
    burialPlace: burialPlace,
    memorialLunarDay: memorialLunarDay,
    memorialLunarMonth: memorialLunarMonth,
    memorialIsLeap: memorialIsLeap,
    notes: notes,
  );
}

Map<String, dynamic> _payload(Person p, PersonFormValues v) {
  return buildPersonUpdatePayload(p, v, nowYear: _now);
}

Map<PersonField, String> _errors(PersonFormValues v) {
  return validatePersonForm(v, nowYear: _now);
}

void main() {
  group('buildPersonUpdatePayload', () {
    test('không đổi gì -> payload rỗng', () {
      final p = _person(
        birthDate: DateTime(1950, 3, 5),
        birthYear: 1950,
        birthPlace: 'Huế',
        notes: 'abc',
      );
      expect(_payload(p, PersonFormValues.fromPerson(p)), isEmpty);
    });

    test('khoảng trắng thừa không tạo thay đổi', () {
      final p = _person(fullName: 'Nguyễn  Văn Nhì');
      final v = PersonFormValues.fromPerson(p)..fullName = ' Nguyễn Văn Nhì  ';
      expect(_payload(p, v), isEmpty);
    });

    test('đổi một cột', () {
      final p = _person();
      final v = PersonFormValues.fromPerson(p)..otherName = 'Hai';
      expect(_payload(p, v), {'other_name': 'Hai'});
    });

    test('xóa trắng ô -> null', () {
      final p = _person(otherName: 'Tí');
      final v = PersonFormValues.fromPerson(p)..otherName = '  ';
      expect(_payload(p, v), {'other_name': null});
    });

    test('chỉ nhập năm sinh', () {
      final p = _person();
      final v = PersonFormValues.fromPerson(p)..birthYear = '1950';
      expect(_payload(p, v), {'birth_year': 1950});
    });

    test('đủ ngày tháng năm sinh', () {
      final p = _person();
      final v = PersonFormValues.fromPerson(p)
        ..birthDay = '5'
        ..birthMonth = '3'
        ..birthYear = '1950';
      expect(_payload(p, v), {'birth_date': '1950-03-05', 'birth_year': 1950});
    });

    test('từ đủ ngày về chỉ năm -> birth_date null', () {
      final p = _person(birthDate: DateTime(1950, 3, 5), birthYear: 1950);
      final v = PersonFormValues.fromPerson(p)
        ..birthDay = ''
        ..birthMonth = '';
      expect(_payload(p, v), {'birth_date': null});
    });

    test('có ngày nhưng database thiếu birth_year: không đổi thì không gửi', () {
      final p = _person(birthDate: DateTime(1950, 3, 5));
      expect(_payload(p, PersonFormValues.fromPerson(p)), isEmpty);
    });

    test('còn sống -> đã mất', () {
      final p = _person();
      final v = PersonFormValues.fromPerson(p)
        ..isAlive = false
        ..deathYear = '2020'
        ..burialPlace = 'Huế'
        ..memorialDay = '15'
        ..memorialMonth = '7'
        ..memorialIsLeap = true;
      expect(_payload(p, v), {
        'is_alive': false,
        'death_year': 2020,
        'burial_place': 'Huế',
        'memorial_lunar_day': 15,
        'memorial_lunar_month': 7,
        'memorial_is_leap': true,
      });
    });

    test('đã mất -> còn sống: xóa dữ liệu mất và giỗ', () {
      final p = _person(
        isAlive: false,
        deathDate: DateTime(2019, 6, 1),
        deathYear: 2019,
        burialPlace: 'Huế',
        memorialLunarDay: 20,
        memorialLunarMonth: 12,
        memorialIsLeap: true,
      );
      final v = PersonFormValues.fromPerson(p)..isAlive = true;
      expect(_payload(p, v), {
        'is_alive': true,
        'death_date': null,
        'death_year': null,
        'burial_place': null,
        'memorial_lunar_day': null,
        'memorial_lunar_month': null,
        'memorial_is_leap': false,
      });
    });

    test('vốn còn sống, không đổi, dù có dữ liệu mất thừa -> không gửi', () {
      final p = _person(deathYear: 2000, burialPlace: 'X');
      expect(_payload(p, PersonFormValues.fromPerson(p)), isEmpty);
    });

    test('đổi giới tính và chi/nhánh', () {
      final p = _person();
      final v = PersonFormValues.fromPerson(p)
        ..gender = Gender.female
        ..branchId = 'b1';
      expect(_payload(p, v), {'gender': 'female', 'branch_id': 'b1'});
    });

    test('bỏ chi/nhánh -> branch_id null', () {
      final p = _person(branchId: 'b1');
      final v = PersonFormValues.fromPerson(p)..branchId = null;
      expect(_payload(p, v), {'branch_id': null});
    });

    test('dữ liệu không hợp lệ -> ném ArgumentError', () {
      final p = _person();
      final v = PersonFormValues.fromPerson(p)..birthYear = 'abc';
      expect(() => _payload(p, v), throwsArgumentError);
    });

    test('ghi chú: bỏ xuống dòng thừa ở cuối thì không tính là đổi', () {
      final p = _person(notes: 'a\nb');
      final v = PersonFormValues.fromPerson(p)..notes = 'a\nb\n';
      expect(_payload(p, v), isEmpty);
    });
  });

  group('validatePersonForm', () {
    test('họ tên chỉ có khoảng trắng', () {
      final v = PersonFormValues(fullName: '   ');
      expect(_errors(v)[PersonField.fullName], isNotNull);
    });

    test('họ tên 1 ký tự', () {
      final v = PersonFormValues(fullName: 'A');
      expect(_errors(v)[PersonField.fullName], isNotNull);
    });

    test('dữ liệu từ một người có thật -> hợp lệ', () {
      final p = _person(birthDate: DateTime(1950, 3, 5), birthYear: 1950);
      expect(_errors(PersonFormValues.fromPerson(p)), isEmpty);
    });

    test('ngày sinh thiếu năm', () {
      final v = PersonFormValues(
        fullName: 'Nguyễn Văn A',
        birthDay: '5',
        birthMonth: '3',
      );
      expect(_errors(v)[PersonField.birth], isNotNull);
    });

    test('31/2 không có thật', () {
      final v = PersonFormValues(
        fullName: 'Nguyễn Văn A',
        birthDay: '31',
        birthMonth: '2',
        birthYear: '1950',
      );
      expect(_errors(v)[PersonField.birth], isNotNull);
    });

    test('tháng 13', () {
      final v = PersonFormValues(
        fullName: 'Nguyễn Văn A',
        birthDay: '5',
        birthMonth: '13',
        birthYear: '1950',
      );
      expect(_errors(v)[PersonField.birth], isNotNull);
    });

    test('năm quá nhỏ (999)', () {
      final v = PersonFormValues(fullName: 'Nguyễn Văn A', birthYear: '999');
      expect(_errors(v)[PersonField.birth], isNotNull);
    });

    test('năm trong tương lai', () {
      final v = PersonFormValues(fullName: 'Nguyễn Văn A', birthYear: '2027');
      expect(_errors(v)[PersonField.birth], isNotNull);
    });

    test('có ngày mà thiếu tháng', () {
      final v = PersonFormValues(
        fullName: 'Nguyễn Văn A',
        birthDay: '5',
        birthYear: '1950',
      );
      expect(_errors(v)[PersonField.birth], isNotNull);
    });

    test('năm mất nhỏ hơn năm sinh', () {
      final v = PersonFormValues(
        fullName: 'Nguyễn Văn A',
        birthYear: '1950',
        isAlive: false,
        deathYear: '1940',
      );
      expect(_errors(v)[PersonField.death], isNotNull);
    });

    test('ngày mất trước ngày sinh (cùng năm)', () {
      final v = PersonFormValues(
        fullName: 'Nguyễn Văn A',
        birthDay: '10',
        birthMonth: '5',
        birthYear: '1950',
        isAlive: false,
        deathDay: '9',
        deathMonth: '5',
        deathYear: '1950',
      );
      expect(_errors(v)[PersonField.death], isNotNull);
    });

    test('còn sống: bỏ qua lỗi ở ô mất và giỗ', () {
      final v = PersonFormValues(
        fullName: 'Nguyễn Văn A',
        deathYear: 'abc',
        memorialDay: '99',
      );
      expect(_errors(v), isEmpty);
    });

    test('giỗ chỉ có ngày', () {
      final v = PersonFormValues(
        fullName: 'Nguyễn Văn A',
        isAlive: false,
        memorialDay: '15',
      );
      expect(_errors(v)[PersonField.memorial], isNotNull);
    });

    test('giỗ ngày 31', () {
      final v = PersonFormValues(
        fullName: 'Nguyễn Văn A',
        isAlive: false,
        memorialDay: '31',
        memorialMonth: '1',
      );
      expect(_errors(v)[PersonField.memorial], isNotNull);
    });

    test('giỗ tháng 13', () {
      final v = PersonFormValues(
        fullName: 'Nguyễn Văn A',
        isAlive: false,
        memorialDay: '1',
        memorialMonth: '13',
      );
      expect(_errors(v)[PersonField.memorial], isNotNull);
    });

    test('giỗ hợp lệ: 30/12 và 1/1', () {
      final a = PersonFormValues(
        fullName: 'Nguyễn Văn A',
        isAlive: false,
        memorialDay: '30',
        memorialMonth: '12',
      );
      final b = PersonFormValues(
        fullName: 'Nguyễn Văn A',
        isAlive: false,
        memorialDay: '1',
        memorialMonth: '1',
      );
      expect(_errors(a), isEmpty);
      expect(_errors(b), isEmpty);
    });
  });

  group('parseDateParts', () {
    test('cả ba ô trống', () {
      final r = parseDateParts(day: '', month: '', year: '', nowYear: _now);
      expect(r.isEmpty, isTrue);
    });

    test('chỉ có năm', () {
      final r = parseDateParts(day: '', month: '', year: '1950', nowYear: _now);
      expect(r.year, 1950);
      expect(r.date, isNull);
      expect(r.error, isNull);
    });

    test('đủ ngày tháng năm', () {
      final r = parseDateParts(day: '5', month: '3', year: '1950', nowYear: _now);
      expect(r.date, DateTime(1950, 3, 5));
      expect(r.year, 1950);
    });
  });

  group('PersonFormValues', () {
    test('fromPerson hai lần thì giống nhau', () {
      final p = _person(birthDate: DateTime(1950, 3, 5), birthYear: 1950);
      final a = PersonFormValues.fromPerson(p);
      expect(a.sameAs(PersonFormValues.fromPerson(p)), isTrue);
    });

    test('đổi một ô thì khác', () {
      final p = _person();
      final a = PersonFormValues.fromPerson(p);
      final b = PersonFormValues.fromPerson(p)..fullName = 'X';
      expect(a.sameAs(b), isFalse);
    });
  });
}