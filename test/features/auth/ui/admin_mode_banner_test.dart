import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:familytree/core/theme/app_colors.dart';
import 'package:familytree/features/auth/ui/admin_shell.dart';

void main() {
  Future<void> pumpBanner(WidgetTester tester) {
    return tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Column(children: [AdminModeBanner()])),
      ),
    );
  }

  testWidgets('dải quản trị nền xanh thông tin, chữ trắng, cao 32', (
    tester,
  ) async {
    await pumpBanner(tester);

    expect(find.text('Chế độ quản trị viên'), findsOneWidget);
    expect(find.byIcon(Icons.admin_panel_settings_outlined), findsOneWidget);

    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(AdminModeBanner),
        matching: find.byType(Material),
      ),
    );
    expect(material.color, AppColors.info);

    final text = tester.widget<Text>(find.text('Chế độ quản trị viên'));
    expect(text.style?.color, Colors.white);

    expect(tester.getSize(find.byType(AdminModeBanner)).height, 32);
  });

  testWidgets('thanh trạng thái dùng biểu tượng sáng khi có dải', (
    tester,
  ) async {
    await pumpBanner(tester);

    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.descendant(
        of: find.byType(AdminModeBanner),
        matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      ),
    );
    expect(region.value.statusBarIconBrightness, Brightness.light);
  });
}
