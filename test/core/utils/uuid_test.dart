import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:familytree/core/utils/uuid.dart';

void main() {
  final v4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  test('đúng định dạng UUID v4', () {
    for (var i = 0; i < 100; i++) {
      expect(generateUuidV4(), matches(v4));
    }
  });

  test('1000 id không trùng nhau', () {
    final ids = {for (var i = 0; i < 1000; i++) generateUuidV4()};
    expect(ids.length, 1000);
  });

  test('cùng hạt giống cho cùng kết quả', () {
    expect(
      generateUuidV4(random: Random(42)),
      generateUuidV4(random: Random(42)),
    );
  });
}