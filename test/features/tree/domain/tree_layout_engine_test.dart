import 'package:familytree/features/tree/domain/family_node.dart';
import 'package:familytree/features/tree/domain/parent_child.dart';
import 'package:familytree/features/tree/domain/tree_layout.dart';
import 'package:familytree/features/tree/domain/tree_layout_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sample_family.dart';

void main() {
  const cfg = TreeLayoutConfig();
  late FamilyForest forest;
  late TreeLayout layout;

  setUp(() {
    forest = buildSampleForest();
    layout = TreeLayoutEngine.compute(forest, config: cfg);
  });

  test('mỗi người trong 16 người có đúng 1 thẻ', () {
    expect(layout.cards.length, 16);
    expect(layout.cardById.length, 16);
  });

  test('không có hai thẻ nào chồng lấn', () {
    for (var i = 0; i < layout.cards.length; i++) {
      for (var j = i + 1; j < layout.cards.length; j++) {
        expect(
          layout.cards[i].rect.overlaps(layout.cards[j].rect),
          isFalse,
          reason: '${layout.cards[i].person.fullName} chồng lấn '
              '${layout.cards[j].person.fullName}',
        );
      }
    }
  });

  test('con luôn nằm ngay dưới hàng của cha mẹ', () {
    final childLinks =
        layout.links.where((l) => l.kind == LinkKind.child).toList();
    expect(childLinks.length, 10);
    for (final l in childLinks) {
      final parent = layout.cardById[l.ownerId]!;
      final child = layout.cardById[l.childId]!;
      expect(child.row, parent.row + 1);
      expect(child.rect.top, parent.rect.bottom + cfg.levelGap);
    }
  });

  test('vợ/chồng xếp nối tiếp người chính theo thứ tự hôn nhân', () {
    final c03 = layout.cardById['03']!;
    final c06 = layout.cardById['06']!;
    final c08 = layout.cardById['08']!;
    expect(c06.rect.top, c03.rect.top);
    expect(c06.rect.left, c03.rect.right + cfg.spouseGap);
    expect(c08.rect.left, c06.rect.right + cfg.spouseGap);
    expect(c06.isSpouse, isTrue);
    expect(c03.isSpouse, isFalse);
  });

  test('có 5 đường hôn nhân; điểm thả con nằm giữa hai thẻ cặp (người 04)', () {
    expect(layout.links.where((l) => l.kind == LinkKind.marriage).length, 5);
    final c04 = layout.cardById['04']!;
    final c07 = layout.cardById['07']!;
    final link = layout.links.firstWhere(
        (l) => l.kind == LinkKind.child && l.ownerId == '04' && l.childId == '12');
    final midX = (c04.rect.center.dx + c07.rect.center.dx) / 2;
    expect(link.points.first.dx, closeTo(midX, 0.001));
  });

  test('cặp một vợ chồng: điểm thả con căn giữa khối con', () {
    final c12 = layout.cardById['12']!.rect.center.dx;
    final c13 = layout.cardById['13']!.rect.center.dx;
    final link = layout.links.firstWhere(
        (l) => l.kind == LinkKind.child && l.ownerId == '04' && l.childId == '12');
    expect(link.points.first.dx, closeTo((c12 + c13) / 2, 0.001));
  });

  test('con nuôi (16) có đường quan hệ adopted, con ruột (15) là biological', () {
    RelationType? rel(String id) => layout.links
        .firstWhere((l) => l.kind == LinkKind.child && l.childId == id)
        .relation;
    expect(rel('16'), RelationType.adopted);
    expect(rel('15'), RelationType.biological);
  });

  test('mọi điểm đường nối nằm trong kích thước tổng', () {
    for (final l in layout.links) {
      for (final p in l.points) {
        expect(p.dx, inInclusiveRange(0, layout.size.width));
        expect(p.dy, inInclusiveRange(0, layout.size.height));
      }
    }
    for (final c in layout.cards) {
      expect(c.rect.right, lessThanOrEqualTo(layout.size.width));
      expect(c.rect.bottom, lessThanOrEqualTo(layout.size.height));
    }
  });

  test('thu gọn gốc: chỉ còn 2 thẻ (01, 02) và không có đường xuống con', () {
    final collapsed =
        TreeLayoutEngine.compute(forest, config: cfg, collapsedIds: {'01'});
    expect(collapsed.cards.map((c) => c.personId).toSet(), {'01', '02'});
    expect(collapsed.links.where((l) => l.kind == LinkKind.child), isEmpty);
    expect(collapsed.cardById['01']!.isCollapsed, isTrue);
    expect(collapsed.cardById['01']!.hasChildren, isTrue);
  });

  test('thu gọn người 03: con cháu của 03 biến mất, nhánh 04 vẫn còn', () {
    final collapsed =
        TreeLayoutEngine.compute(forest, config: cfg, collapsedIds: {'03'});
    final ids = collapsed.cards.map((c) => c.personId).toSet();
    expect(ids.containsAll({'03', '06', '08', '04', '07', '12', '13'}), isTrue);
    expect(ids.intersection({'09', '10', '11', '14', '15', '16'}), isEmpty);
    for (var i = 0; i < collapsed.cards.length; i++) {
      for (var j = i + 1; j < collapsed.cards.length; j++) {
        expect(collapsed.cards[i].rect.overlaps(collapsed.cards[j].rect), isFalse);
      }
    }
  });

  test('cây rỗng không lỗi', () {
    const empty = FamilyForest(
      roots: [],
      nodeOfPerson: {},
      spouseOnlyIds: {},
      warnings: [],
    );
    final result = TreeLayoutEngine.compute(empty);
    expect(result.cards, isEmpty);
    expect(result.links, isEmpty);
  });
}