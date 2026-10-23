import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/tree/domain/family_node.dart';
import 'package:familytree/features/tree/domain/family_tree_builder.dart';
import 'package:familytree/features/tree/domain/marriage.dart';
import 'package:familytree/features/tree/domain/parent_child.dart';
import 'package:flutter_test/flutter_test.dart';

Person _person(
  String id,
  String name, {
  String gender = 'male',
  int? gen,
  int? birthYear,
  String? birthDate,
}) =>
    Person.fromJson({
      'id': id,
      'full_name': name,
      'other_name': null,
      'gender': gender,
      'branch_id': null,
      'generation': gen,
      'birth_date': birthDate,
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
Marriage _marriage(
  String p1,
  String p2, {
  String status = 'married',
  String? start,
}) =>
    Marriage.fromJson({
      'id': 'm${_mCounter++}',
      'person1_id': p1,
      'person2_id': p2,
      'status': status,
      'start_date': start,
      'end_date': null,
      'notes': null,
    });

List<String> _names(Iterable<FamilyNode> nodes) =>
    nodes.map((n) => n.person.id).toList();

void main() {
  group('Dữ liệu giống bản mẫu (16 người)', () {
    late FamilyForest forest;

    setUp(() {
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
      forest = FamilyTreeBuilder.build(
        people: people,
        parentChildren: parentChildren,
        marriages: marriages,
      );
    });

    test('có đúng 1 gốc là người 01, không có cảnh báo', () {
      expect(_names(forest.roots), ['01']);
      expect(forest.warnings, isEmpty);
    });

    test('vợ/chồng ngoại họ đúng 5 người', () {
      expect(forest.spouseOnlyIds, {'02', '06', '07', '08', '14'});
    });

    test('đời 2: con của 01 xếp theo năm sinh (03, 05, 04)', () {
      final root = forest.roots.first;
      expect(root.unions.length, 1);
      expect(root.unions.first.spouse!.id, '02');
      expect(_names(root.unions.first.children), ['03', '05', '04']);
    });

    test('người 03 có 2 vợ theo thứ tự hôn nhân, con đúng cặp', () {
      final n03 = forest.nodeOfPerson['03']!;
      expect(n03.unions.map((u) => u.spouse!.id), ['06', '08']);
      expect(_names(n03.unions[0].children), ['09', '10']);
      expect(_names(n03.unions[1].children), ['11']);
    });

    test('người 04 và 09 có con đúng, con nuôi (16) có mặt', () {
      expect(_names(forest.nodeOfPerson['04']!.unions.first.children),
          ['12', '13']);
      expect(_names(forest.nodeOfPerson['09']!.unions.first.children),
          ['15', '16']);
    });

    test('mọi người trong 16 đều tra được nút', () {
      expect(forest.nodeOfPerson.length, 16);
      expect(forest.nodeOfPerson['06']!.person.id, '03');
    });
  });

  group('Ca đặc biệt', () {
    test('con chỉ có một cha/mẹ trong dữ liệu: gắn dưới người đó', () {
      final forest = FamilyTreeBuilder.build(
        people: [
          _person('a', 'A', gen: 1),
          _person('b', 'B', gen: 2, birthYear: 1990),
        ],
        parentChildren: [_pc('a', 'b')],
        marriages: [],
      );
      final a = forest.nodeOfPerson['a']!;
      expect(a.unions.length, 1);
      expect(a.unions.first.spouse, isNull);
      expect(_names(a.unions.first.children), ['b']);
    });

    test('cặp cùng là cha mẹ nhưng không có hôn nhân: vẫn tạo cặp, không trùng lặp',
        () {
      final forest = FamilyTreeBuilder.build(
        people: [
          _person('f', 'Cha', gen: 1),
          _person('m', 'Mẹ', gender: 'female', gen: 1),
          _person('c', 'Con', gen: 2),
        ],
        parentChildren: [_pc('f', 'c'), _pc('m', 'c')],
        marriages: [],
      );
      expect(_names(forest.roots), ['f']);
      expect(forest.spouseOnlyIds, {'m'});
      expect(forest.nodeOfPerson['f']!.unions.first.marriage, isNull);
      expect(_names(forest.nodeOfPerson['f']!.unions.first.children), ['c']);
    });

    test('hai vợ/chồng đều có cha mẹ trong cây: chọn đời nhỏ hơn / nam, có cảnh báo',
        () {
      final forest = FamilyTreeBuilder.build(
        people: [
          _person('r', 'Gốc', gen: 1),
          _person('x', 'X', gen: 2, birthYear: 1950),
          _person('y', 'Y', gender: 'female', gen: 2, birthYear: 1951),
        ],
        parentChildren: [_pc('r', 'x'), _pc('r', 'y')],
        marriages: [_marriage('x', 'y')],
      );
      expect(forest.spouseOnlyIds, {'y'});
      expect(forest.warnings.any((w) => w.contains('có cha mẹ trong cây')),
          isTrue);
    });

    test('thiếu ngày hôn nhân: xếp theo năm sinh con đầu', () {
      final forest = FamilyTreeBuilder.build(
        people: [
          _person('h', 'Chồng', gen: 1),
          _person('w1', 'Vợ sau', gender: 'female', gen: 1),
          _person('w2', 'Vợ đầu', gender: 'female', gen: 1),
          _person('c1', 'Con vợ sau', gen: 2, birthYear: 1990),
          _person('c2', 'Con vợ đầu', gen: 2, birthYear: 1970),
        ],
        parentChildren: [
          _pc('h', 'c1'),
          _pc('w1', 'c1'),
          _pc('h', 'c2'),
          _pc('w2', 'c2'),
        ],
        marriages: [_marriage('h', 'w1'), _marriage('h', 'w2')],
      );
      final spouses =
          forest.nodeOfPerson['h']!.unions.map((u) => u.spouse!.id).toList();
      expect(spouses, ['w2', 'w1']);
    });
  });
}