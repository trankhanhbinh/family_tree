import 'package:flutter_test/flutter_test.dart';

import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/person/domain/person_relations.dart';
import 'package:familytree/features/tree/domain/parent_child.dart';

Person _person(String id) {
  return Person(
    id: id,
    fullName: 'Người $id',
    gender: Gender.male,
    isAlive: true,
    memorialIsLeap: false,
  );
}

ParentEntry _parent(String id, RelationType relation) {
  return ParentEntry(person: _person(id), relation: relation);
}

ChildEntry _child(String id, RelationType relation) {
  return ChildEntry(person: _person(id), relation: relation);
}

PersonRelations _relations({
  List<ParentEntry> parents = const [],
  List<ChildEntry> children = const [],
}) {
  return PersonRelations(
    parents: parents,
    spouses: const [],
    children: children,
  );
}

void main() {
  group('parentsHeading', () {
    test('mọi liên kết là nối đời thì "Đời trước"', () {
      final r = _relations(
        parents: [
          _parent('a', RelationType.lineage),
          _parent('b', RelationType.lineage),
        ],
      );
      expect(r.parentsHeading, 'Đời trước');
    });

    test('một liên kết nối đời duy nhất thì "Đời trước"', () {
      final r = _relations(parents: [_parent('a', RelationType.lineage)]);
      expect(r.parentsHeading, 'Đời trước');
    });

    test('lẫn lộn nối đời và ruột thì giữ "Cha mẹ"', () {
      final r = _relations(
        parents: [
          _parent('a', RelationType.lineage),
          _parent('b', RelationType.biological),
        ],
      );
      expect(r.parentsHeading, 'Cha mẹ');
    });

    test('toàn ruột/nuôi/kế thì "Cha mẹ"', () {
      final r = _relations(
        parents: [
          _parent('a', RelationType.biological),
          _parent('b', RelationType.adopted),
          _parent('c', RelationType.step),
        ],
      );
      expect(r.parentsHeading, 'Cha mẹ');
    });

    test('không có liên kết thì "Cha mẹ"', () {
      expect(_relations().parentsHeading, 'Cha mẹ');
    });
  });

  group('childrenHeading', () {
    test('mọi liên kết là nối đời thì "Đời sau"', () {
      final r = _relations(
        children: [
          _child('a', RelationType.lineage),
          _child('b', RelationType.lineage),
        ],
      );
      expect(r.childrenHeading, 'Đời sau');
    });

    test('lẫn lộn nối đời và nuôi thì giữ "Con"', () {
      final r = _relations(
        children: [
          _child('a', RelationType.lineage),
          _child('b', RelationType.adopted),
        ],
      );
      expect(r.childrenHeading, 'Con');
    });

    test('toàn ruột thì "Con"', () {
      final r = _relations(children: [_child('a', RelationType.biological)]);
      expect(r.childrenHeading, 'Con');
    });

    test('không có liên kết thì "Con"', () {
      expect(_relations().childrenHeading, 'Con');
    });

    test('hai mục độc lập: cha mẹ nối đời nhưng con ruột', () {
      final r = _relations(
        parents: [_parent('p', RelationType.lineage)],
        children: [_child('c', RelationType.biological)],
      );
      expect(r.parentsHeading, 'Đời trước');
      expect(r.childrenHeading, 'Con');
    });
  });
}
