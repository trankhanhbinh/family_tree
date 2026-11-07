import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:familytree/features/tree/ui/empty_tree_view.dart';

Widget _wrap({required bool isAdmin, required VoidCallback onAddFirst}) {
  return MaterialApp(
    home: Scaffold(
      body: EmptyTreeView(isAdmin: isAdmin, onAddFirst: onAddFirst),
    ),
  );
}

void main() {
  testWidgets('admin thấy nút và bấm được', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(isAdmin: true, onAddFirst: () => taps++));

    expect(find.text('Gia phả chưa có ai'), findsOneWidget);
    expect(find.text('Thêm người đầu tiên'), findsOneWidget);
    expect(find.text('Quản trị viên sẽ thêm dữ liệu sớm.'), findsNothing);

    await tester.tap(find.text('Thêm người đầu tiên'));
    expect(taps, 1);
  });

  testWidgets('người thường chỉ thấy dòng chữ, không có nút', (tester) async {
    await tester.pumpWidget(_wrap(isAdmin: false, onAddFirst: () {}));

    expect(find.text('Gia phả chưa có ai'), findsOneWidget);
    expect(find.text('Quản trị viên sẽ thêm dữ liệu sớm.'), findsOneWidget);
    expect(find.text('Thêm người đầu tiên'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });
}
