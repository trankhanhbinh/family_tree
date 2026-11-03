import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:familytree/core/config/app_version_provider.dart';
import 'package:familytree/core/ui/app_version_label.dart';

void main() {
  Widget buildApp(Future<String> Function() loader) {
    return ProviderScope(
      overrides: [
        appVersionTextProvider.overrideWith((ref) => loader()),
      ],
      child: const MaterialApp(
        home: Scaffold(body: AppVersionLabel()),
      ),
    );
  }

  testWidgets('hiện số phiên bản khi đọc xong', (tester) async {
    await tester.pumpWidget(
      buildApp(() async => 'Phiên bản 1.0.0 (1)'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Phiên bản 1.0.0 (1)'), findsOneWidget);
  });

  testWidgets('lỗi đọc phiên bản thì không hiện gì', (tester) async {
    await tester.pumpWidget(
      buildApp(() async => throw Exception('lỗi thử')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Text), findsNothing);
  });
}