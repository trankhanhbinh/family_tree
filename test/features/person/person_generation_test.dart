import 'package:flutter_test/flutter_test.dart';
import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/person/domain/person_edit_form.dart';

Person _person({Object? generation}) {
  return Person.fromJson({
    'id': 'a0000000-0000-0000-0000-000000000001',
    'full_name': 'Nguyễn Văn Tổ',
    'other_name': null,
    'gender': 'male',
    'branch_id': null,
    'generation': generation,
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

void main() {
  group('parseGeneration', () {
    test('trống -> null, không lỗi', () {
      final r = parseGeneration('  ');
      expect(r.value, isNull);
      expect(r.error, isNull);
    });

    test('1 và 50 là hợp lệ', () {
      expect(parseGeneration('1').value, 1);
      expect(parseGeneration(' 50 ').value, 50);
    });

    test('0, 51 và chữ -> báo lỗi', () {
      expect(parseGeneration('0').error, isNotNull);
      expect(parseGeneration('51').error, isNotNull);
      expect(parseGeneration('abc').error, isNotNull);
    });
  });

  group('validatePersonForm với số đời', () {
    test('admin: số đời sai -> lỗi ở PersonField.generation', () {
      final values = PersonFormValues(fullName: 'Nguyễn Văn A', generation: 'x');
      final errors =
          validatePersonForm(values, nowYear: 2026, validateGeneration: true);
      expect(errors.containsKey(PersonField.generation), isTrue);
    });

    test('người thường: số đời sai KHÔNG bị kiểm tra', () {
      final values = PersonFormValues(fullName: 'Nguyễn Văn A', generation: 'x');
      final errors = validatePersonForm(values, nowYear: 2026);
      expect(errors, isEmpty);
    });
  });

  group('buildPersonUpdatePayload với số đời', () {
    test('includeGeneration = false: không bao giờ có khóa generation', () {
      final original = _person(generation: 2);
      final values = PersonFormValues.fromPerson(original)..generation = '9';
      final payload =
          buildPersonUpdatePayload(original, values, nowYear: 2026);
      expect(payload, isEmpty);
    });

    test('includeGeneration = true: đổi số đời -> chỉ gửi generation', () {
      final original = _person(generation: 2);
      final values = PersonFormValues.fromPerson(original)..generation = '3';
      final payload = buildPersonUpdatePayload(
        original,
        values,
        nowYear: 2026,
        includeGeneration: true,
      );
      expect(payload, {'generation': 3});
    });

    test('includeGeneration = true: xóa trắng số đời đang có -> null', () {
      final original = _person(generation: 2);
      final values = PersonFormValues.fromPerson(original)..generation = '';
      final payload = buildPersonUpdatePayload(
        original,
        values,
        nowYear: 2026,
        includeGeneration: true,
      );
      expect(payload, {'generation': null});
    });
  });
}