import 'package:flutter_test/flutter_test.dart';
import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/person/domain/person_create.dart';
import 'package:familytree/features/person/domain/person_edit_form.dart';
import 'package:familytree/features/tree/domain/parent_child.dart';

Person _person({required int generation}) {
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

PersonFormValues _values({String generation = ''}) {
  return PersonFormValues(fullName: 'Nguyễn Văn B', generation: generation);
}

Object? _generationOf(List<dynamic> drafts) => drafts.first.payload['generation'];

void main() {
  group('planAddChild', () {
    test('mặc định: đời con = đời cha/mẹ + 1', () {
      final drafts = planAddChild(
        values: _values(generation: '9'),
        childId: 'c1',
        parent: _person(generation: 2),
        relation: RelationType.biological,
        nowYear: 2026,
      );
      expect(_generationOf(drafts), 3);
    });

    test('admin nhập số đời 5 -> dùng 5', () {
      final drafts = planAddChild(
        values: _values(generation: '5'),
        childId: 'c1',
        parent: _person(generation: 2),
        relation: RelationType.biological,
        nowYear: 2026,
        useFormGeneration: true,
      );
      expect(_generationOf(drafts), 5);
    });

    test('admin để trống số đời -> tự tính (đời cha/mẹ + 1)', () {
      final drafts = planAddChild(
        values: _values(),
        childId: 'c1',
        parent: _person(generation: 2),
        relation: RelationType.biological,
        nowYear: 2026,
        useFormGeneration: true,
      );
      expect(_generationOf(drafts), 3);
    });

    test('người thường: ô số đời trong form bị bỏ qua', () {
      final drafts = planAddChild(
        values: _values(generation: '5'),
        childId: 'c1',
        parent: _person(generation: 2),
        relation: RelationType.biological,
        nowYear: 2026,
      );
      expect(_generationOf(drafts), 3);
    });
  });

  group('planAddSpouse', () {
    test('mặc định: đời = đời của bạn đời', () {
      final drafts = planAddSpouse(
        values: _values(generation: '9'),
        spouseId: 's1',
        partner: _person(generation: 4),
        marriage: MarriageFormValues(),
        nowYear: 2026,
      );
      expect(_generationOf(drafts), 4);
    });

    test('admin nhập số đời 6 -> dùng 6', () {
      final drafts = planAddSpouse(
        values: _values(generation: '6'),
        spouseId: 's1',
        partner: _person(generation: 4),
        marriage: MarriageFormValues(),
        nowYear: 2026,
        useFormGeneration: true,
      );
      expect(_generationOf(drafts), 6);
    });

    test('người thường: ô số đời trong form bị bỏ qua', () {
      final drafts = planAddSpouse(
        values: _values(generation: '6'),
        spouseId: 's1',
        partner: _person(generation: 4),
        marriage: MarriageFormValues(),
        nowYear: 2026,
      );
      expect(_generationOf(drafts), 4);
    });
  });
}