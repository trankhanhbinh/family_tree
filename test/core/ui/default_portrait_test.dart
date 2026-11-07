import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:familytree/core/ui/default_portrait.dart';

void main() {
  testWidgets('DefaultPortrait có tỉ lệ 3:4', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: DefaultPortrait(width: 42, accent: Colors.blue)),
      ),
    );
    final size = tester.getSize(find.byType(DefaultPortrait));
    expect(size.width, 42);
    expect(size.height, closeTo(56, 0.001));
    expect(tester.takeException(), isNull);
  });

  test('paintPortraitFigure vẽ được trong khung bất kỳ', () {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    paintPortraitFigure(canvas, const Rect.fromLTWH(10, 20, 44, 58));
    paintPortraitFigure(canvas, const Rect.fromLTWH(0, 0, 84, 112));
    recorder.endRecording().dispose();
  });
}
