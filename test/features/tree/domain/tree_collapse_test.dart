import 'package:familytree/features/tree/data/collapsed_ids_provider.dart';
import 'package:familytree/features/tree/domain/collapse_utils.dart';
import 'package:familytree/features/tree/domain/family_node.dart';
import 'package:familytree/features/tree/domain/tree_layout.dart';
import 'package:familytree/features/tree/domain/tree_layout_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  test('descendantCount: 01 = 10, 03 = 5, 04 = 2, 09 = 2', () {
    expect(layout.cardById['01']!.descendantCount, 10);
    expect(layout.cardById['03']!.descendantCount, 5);
    expect(layout.cardById['04']!.descendantCount, 2);
    expect(layout.cardById['09']!.descendantCount, 2);
  });

  test('descendantCount không tính vợ/chồng và bằng 0 với thẻ lá, thẻ vợ/chồng',
      () {
    expect(layout.cardById['05']!.descendantCount, 0);
    expect(layout.cardById['02']!.descendantCount, 0);
    expect(layout.cardById['15']!.descendantCount, 0);
  });

  test('descendantCount không đổi khi thu gọn (đếm trên toàn cây)', () {
    final collapsed =
        TreeLayoutEngine.compute(forest, config: cfg, collapsedIds: {'03'});
    expect(collapsed.cardById['03']!.descendantCount, 5);
    expect(collapsed.cardById['01']!.descendantCount, 10);
  });

  test('footerRect chỉ có ở người chính có con, nằm sát đáy thẻ', () {
    for (final id in ['01', '03', '04', '09']) {
      final card = layout.cardById[id]!;
      final footer = card.footerRect;
      expect(footer, isNotNull, reason: 'người $id phải có dải');
      expect(footer!.bottom, card.rect.bottom);
      expect(footer.left, card.rect.left);
      expect(footer.width, card.rect.width);
      expect(footer.height, cfg.footerHeight);
    }
    for (final id in ['02', '05', '06', '10', '15', '16']) {
      expect(layout.cardById[id]!.footerRect, isNull,
          reason: 'người $id không được có dải');
    }
  });

  test('collapsibleNonRootIds: chỉ người chính hàng >= 1 có con = {03, 04, 09}',
      () {
    expect(collapsibleNonRootIds(forest), {'03', '04', '09'});
  });

  test('thu gọn tất cả: còn gốc + đời 2 (8 thẻ), gốc vẫn mở', () {
    final ids = collapsibleNonRootIds(forest);
    final collapsed =
        TreeLayoutEngine.compute(forest, config: cfg, collapsedIds: ids);
    expect(
      collapsed.cards.map((c) => c.personId).toSet(),
      {'01', '02', '03', '06', '08', '04', '07', '05'},
    );
    expect(collapsed.cardById['01']!.isCollapsed, isFalse);
    expect(collapsed.cardById['03']!.isCollapsed, isTrue);
    expect(collapsed.cardById['04']!.isCollapsed, isTrue);
  });

  test('collapsedIds chứa id không còn tồn tại thì bị bỏ qua, không lỗi', () {
    final result = TreeLayoutEngine.compute(
      forest,
      config: cfg,
      collapsedIds: {'khong-ton-tai'},
    );
    expect(result.cards.length, 16);
  });

  group('collapsedIdsProvider', () {
    test('mặc định rỗng; toggle bật rồi tắt', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(collapsedIdsProvider.notifier);

      expect(container.read(collapsedIdsProvider), isEmpty);
      notifier.toggle('03');
      expect(container.read(collapsedIdsProvider), {'03'});
      notifier.toggle('03');
      expect(container.read(collapsedIdsProvider), isEmpty);
    });

    test('collapseAll rồi expandAll', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(collapsedIdsProvider.notifier);

      notifier.collapseAll({'03', '04', '09'});
      expect(container.read(collapsedIdsProvider), {'03', '04', '09'});
      notifier.expandAll();
      expect(container.read(collapsedIdsProvider), isEmpty);
    });
  });
}