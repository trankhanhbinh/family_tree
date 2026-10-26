import 'dart:ui';

import 'package:familytree/features/tree/domain/tree_layout.dart';
import 'package:familytree/features/tree/domain/tree_layout_engine.dart';
import 'package:familytree/features/tree/ui/tree_painter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sample_family.dart';

void main() {
  late TreeLayout layout;
  late TreeScene scene;

  setUp(() {
    layout = TreeLayoutEngine.compute(buildSampleForest());
    scene = TreeScene(layout);
  });

  test('TreeScene dựng đủ đường: 5 hôn nhân, 10 đường con (1 nét đứt)', () {
    expect(scene.marriageLinks.length, 5);
    expect(scene.childDashed.length, 1);
    expect(scene.childSolid.length, 9);
  });

  test('vùng nhìn bao cả cây: mọi thẻ đều được chọn', () {
    final all = Offset.zero & layout.size;
    expect(scene.cardsIn(all).length, 16);
  });

  test('vùng nhìn rất xa cây: không thẻ nào được chọn', () {
    final far = Rect.fromLTWH(
      layout.size.width + 5000,
      layout.size.height + 5000,
      400,
      400,
    );
    expect(scene.cardsIn(far), isEmpty);
  });

  test('vùng nhìn nhỏ quanh một thẻ chỉ chọn một phần thẻ', () {
    final area = layout.cards.first.rect.inflate(10);
    final visible = scene.cardsIn(area);
    expect(visible, isNotEmpty);
    expect(visible.length, lessThan(16));
  });

  test('mọi LinkShape có khung bao không rỗng', () {
    final shapes = [
      ...scene.marriageLinks,
      ...scene.childDashed,
      ...scene.childSolid,
    ];
    for (final s in shapes) {
      expect(s.bounds.isEmpty, isFalse);
    }
  });
}