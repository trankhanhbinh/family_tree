import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/tree/domain/family_node.dart';
import 'package:familytree/features/tree/domain/family_tree_builder.dart';
import 'package:familytree/features/tree/domain/marriage.dart';
import 'package:familytree/features/tree/domain/parent_child.dart';

Person _person(String id, String name,
        {String gender = 'male', int? gen, int? birthYear}) =>
    Person.fromJson({
      'id': id,
      'full_name': name,
      'other_name': null,
      'gender': gender,
      'branch_id': null,
      'generation': gen,
      'birth_date': null,
      'birth_year': birthYear,
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

int _pcCounter = 0;
ParentChild _pc(String parent, String child, [String type = 'biological']) =>
    ParentChild.fromJson({
      'id': 'pc${_pcCounter++}',
      'parent_id': parent,
      'child_id': child,
      'relation_type': type,
    });

int _mCounter = 0;
Marriage _marriage(String p1, String p2,
        {String status = 'married', String? start}) =>
    Marriage.fromJson({
      'id': 'm${_mCounter++}',
      'person1_id': p1,
      'person2_id': p2,
      'status': status,
      'start_date': start,
      'end_date': null,
      'notes': null,
    });

/// Cây 16 người có cấu trúc giống dữ liệu mẫu trong database.
FamilyForest buildSampleForest() {
  final people = [
    _person('01', 'Tổ', gen: 1, birthYear: 1920),
    _person('02', 'Hoa', gender: 'female', gen: 1, birthYear: 1925),
    _person('03', 'Nhất', gen: 2, birthYear: 1945),
    _person('04', 'Nhì', gen: 2, birthYear: 1950),
    _person('05', 'Lan', gender: 'female', gen: 2, birthYear: 1948),
    _person('06', 'Mai', gender: 'female', gen: 2, birthYear: 1946),
    _person('07', 'Cúc', gender: 'female', gen: 2, birthYear: 1952),
    _person('08', 'Hạnh', gender: 'female', gen: 2, birthYear: 1960),
    _person('09', 'Hùng', gen: 3, birthYear: 1970),
    _person('10', 'Hà', gender: 'female', gen: 3, birthYear: 1973),
    _person('11', 'Phúc', gen: 3, birthYear: 1988),
    _person('12', 'Quang', gen: 3, birthYear: 1980),
    _person('13', 'Ngọc', gender: 'female', gen: 3, birthYear: 1983),
    _person('14', 'Thu', gender: 'female', gen: 3, birthYear: 1972),
    _person('15', 'Khoa', gen: 4, birthYear: 2004),
    _person('16', 'An', gender: 'female', gen: 4, birthYear: 2008),
  ];
  final parentChildren = [
    for (final c in ['03', '04', '05']) ...[_pc('01', c), _pc('02', c)],
    for (final c in ['09', '10']) ...[_pc('03', c), _pc('06', c)],
    _pc('03', '11'),
    _pc('08', '11'),
    for (final c in ['12', '13']) ...[_pc('04', c), _pc('07', c)],
    _pc('09', '15'),
    _pc('14', '15'),
    _pc('09', '16', 'adopted'),
    _pc('14', '16', 'adopted'),
  ];
  final marriages = [
    _marriage('01', '02', status: 'widowed'),
    _marriage('03', '06', status: 'divorced', start: '1972-01-01'),
    _marriage('03', '08', status: 'widowed', start: '1986-01-01'),
    _marriage('04', '07', start: '1978-01-01'),
    _marriage('09', '14', start: '2002-01-01'),
  ];
  return FamilyTreeBuilder.build(
    people: people,
    parentChildren: parentChildren,
    marriages: marriages,
  );
}