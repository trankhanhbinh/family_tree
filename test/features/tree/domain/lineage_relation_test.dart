import 'package:flutter_test/flutter_test.dart';

import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/person/domain/person_create.dart';
import 'package:familytree/features/person/domain/person_relations.dart';
import 'package:familytree/features/person/domain/relation_changes.dart';
import 'package:familytree/features/tree/domain/family_node.dart';
import 'package:familytree/features/tree/domain/family_tree_builder.dart';
import 'package:familytree/features/tree/domain/parent_child.dart';

Person _p(String id) {
  return Person(
    id: id,
    fullName: 'Tổ $id',
    gender: Gender.male,
    isAlive: false,
    memorialIsLeap: false,
  );
}

ParentChild _pc(
  String id,
  String parent,
  String child, [
  RelationType type = RelationType.lineage,
]) {
  return ParentChild(
    id: id,
    parentId: parent,
    childId: child,
    relationType: type,
  );
}

void main() {
  group('RelationType', () {
    test('fromString nhận "lineage"', () {
      expect(RelationType.fromString('lineage'), RelationType.lineage);
    });

    test('fromString: giá trị cũ vẫn đúng, lạ hoặc null -> ruột', () {
      expect(RelationType.fromString('biological'), RelationType.biological);
      expect(RelationType.fromString('adopted'), RelationType.adopted);
      expect(RelationType.fromString('step'), RelationType.step);
      expect(RelationType.fromString(null), RelationType.biological);
      expect(RelationType.fromString('khac'), RelationType.biological);
    });

    test('tên enum chính là mã lưu trong database (khứ hồi)', () {
      for (final type in RelationType.values) {
        expect(RelationType.fromString(type.name), type);
      }
      expect(RelationType.lineage.name, 'lineage');
    });

    test('ParentChild.fromJson đọc được lineage', () {
      final pc = ParentChild.fromJson({
        'id': 'x',
        'parent_id': 'a',
        'child_id': 'b',
        'relation_type': 'lineage',
      });
      expect(pc.relationType, RelationType.lineage);
    });
  });

  group('tạo payload và kế hoạch', () {
    test('payload tạo quan hệ cha-con dùng mã lineage', () {
      final payload = buildParentChildCreatePayload(
        parentId: 'a',
        childId: 'b',
        relation: RelationType.lineage,
      );
      expect(payload['relation_type'], 'lineage');
      expect(payload['parent_id'], 'a');
      expect(payload['child_id'], 'b');
    });

    test('đổi loại quan hệ sang nối đời', () {
      final drafts = planChangeRelationType(
        childId: 'c',
        parentChildren: [_pc('r1', 'a', 'c', RelationType.biological)],
        newType: RelationType.lineage,
      );
      expect(drafts.length, 1);
      expect(drafts.first.payload, {'relation_type': 'lineage'});
    });

    test('đã là nối đời thì không cần đổi', () {
      final drafts = planChangeRelationType(
        childId: 'c',
        parentChildren: [_pc('r1', 'a', 'c')],
        newType: RelationType.lineage,
      );
      expect(drafts, isEmpty);
    });
  });

  group('dựng cây và quan hệ', () {
    test('chuỗi tổ tiên nối đời thành một nhánh liền, gốc là đời đầu', () {
      final FamilyForest forest = FamilyTreeBuilder.build(
        people: [_p('a1'), _p('a2'), _p('a3')],
        parentChildren: [_pc('r1', 'a1', 'a2'), _pc('r2', 'a2', 'a3')],
        marriages: [],
      );
      expect(forest.roots.map((n) => n.person.id).toList(), ['a1']);

      final UnionGroup first = forest.nodeOfPerson['a1']!.unions.first;
      expect(first.children.map((n) => n.person.id).toList(), ['a2']);
      expect(first.childRelations['a2'], RelationType.lineage);

      final UnionGroup second = forest.nodeOfPerson['a2']!.unions.first;
      expect(second.children.map((n) => n.person.id).toList(), ['a3']);
      expect(second.childRelations['a3'], RelationType.lineage);
    });

    test('PersonRelations giữ loại nối đời ở cả hai phía', () {
      final people = [_p('a'), _p('b')];
      final rows = [_pc('r1', 'a', 'b')];

      final ofChild = PersonRelations.of(
        'b',
        people: people,
        parentChildren: rows,
        marriages: [],
      );
      expect(ofChild.parents.single.person.id, 'a');
      expect(ofChild.parents.single.relation, RelationType.lineage);

      final ofParent = PersonRelations.of(
        'a',
        people: people,
        parentChildren: rows,
        marriages: [],
      );
      expect(ofParent.children.single.person.id, 'b');
      expect(ofParent.children.single.relation, RelationType.lineage);
    });
  });
}
