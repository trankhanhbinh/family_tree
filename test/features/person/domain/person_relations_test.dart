import 'package:flutter_test/flutter_test.dart';
import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/person/domain/person_relations.dart';
import 'package:familytree/features/tree/domain/marriage.dart';
import 'package:familytree/features/tree/domain/parent_child.dart';

Person _person(
  String id, {
  String gender = 'male',
  int? birthYear,
}) {
  return Person.fromJson({
    'id': id,
    'full_name': 'Người $id',
    'other_name': null,
    'gender': gender,
    'branch_id': null,
    'generation': 1,
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
}

ParentChild _pc(
  String id,
  String parent,
  String child, {
  String type = 'biological',
}) {
  return ParentChild.fromJson({
    'id': id,
    'parent_id': parent,
    'child_id': child,
    'relation_type': type,
  });
}

Marriage _marriage(
  String id,
  String p1,
  String p2, {
  String status = 'married',
  String? start,
}) {
  return Marriage.fromJson({
    'id': id,
    'person1_id': p1,
    'person2_id': p2,
    'status': status,
    'start_date': start,
    'end_date': null,
    'notes': null,
  });
}

void main() {
  // a (nam) có 2 vợ: b (ly hôn, 1985) và c (kết hôn, 1998).
  // Con: k1 (a+b, 1990), k2 (a+b, nuôi, 1992), k3 (a+c, 2000), k4 (a+c, không rõ năm sinh).
  // s: con có cha kế a và mẹ ruột b.
  final people = [
    _person('a'),
    _person('b', gender: 'female'),
    _person('c', gender: 'female'),
    _person('k1', birthYear: 1990),
    _person('k2', birthYear: 1992),
    _person('k3', birthYear: 2000),
    _person('k4'),
    _person('s', birthYear: 1995),
    _person('lone'),
  ];

  final parentChildren = [
    _pc('1', 'b', 'k1'), // mẹ đứng trước cha để thử thứ tự
    _pc('2', 'a', 'k1'),
    _pc('3', 'a', 'k2', type: 'adopted'),
    _pc('4', 'b', 'k2', type: 'adopted'),
    _pc('5', 'a', 'k3'),
    _pc('6', 'c', 'k3'),
    _pc('7', 'a', 'k4'),
    _pc('8', 'c', 'k4'),
    _pc('9', 'a', 's', type: 'step'),
    _pc('10', 'b', 's'),
  ];

  // Đặt hôn nhân của c trước để thử việc sắp xếp theo ngày bắt đầu.
  final marriages = [
    _marriage('m2', 'a', 'c', start: '1998-06-01'),
    _marriage('m1', 'a', 'b', status: 'divorced', start: '1985-01-01'),
  ];

  PersonRelations relationsOf(String id) => PersonRelations.of(
        id,
        people: people,
        parentChildren: parentChildren,
        marriages: marriages,
      );

  test('con xếp theo năm sinh, không rõ xếp cuối, không trùng lặp', () {
    final children = relationsOf('a').children;
    expect(children.map((e) => e.person.id).toList(), [
      'k1',
      's',
      'k2',
      'k3',
      'k4',
    ]);
    final k2 = children.firstWhere((e) => e.person.id == 'k2');
    expect(k2.relation, RelationType.adopted);
    final s = children.firstWhere((e) => e.person.id == 's');
    expect(s.relation, RelationType.step);
  });

  test('cha mẹ: nam trước nữ', () {
    final parents = relationsOf('k1').parents;
    expect(parents.map((e) => e.person.id).toList(), ['a', 'b']);
  });

  test('cha mẹ: quan hệ kế xếp sau quan hệ ruột', () {
    final parents = relationsOf('s').parents;
    expect(parents.map((e) => e.person.id).toList(), ['b', 'a']);
    expect(parents.first.relation, RelationType.biological);
    expect(parents.last.relation, RelationType.step);
  });

  test('vợ/chồng xếp theo ngày bắt đầu hôn nhân', () {
    final spouses = relationsOf('a').spouses;
    expect(spouses.map((e) => e.person.id).toList(), ['b', 'c']);
    expect(spouses.first.marriage.status, MarriageStatus.divorced);
    expect(spouses.last.marriage.status, MarriageStatus.married);
  });

  test('tìm vợ/chồng từ phía người còn lại', () {
    final spouses = relationsOf('c').spouses;
    expect(spouses.map((e) => e.person.id).toList(), ['a']);
  });

  test('người không có quan hệ nào', () {
    expect(relationsOf('lone').isEmpty, isTrue);
  });
}