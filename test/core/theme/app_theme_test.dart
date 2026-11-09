import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:familytree/core/theme/app_colors.dart';
import 'package:familytree/core/theme/app_theme.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  final theme = AppTheme.light();
  final scheme = theme.colorScheme;

  test('màu chính và nền theo bảng màu mới', () {
    expect(AppColors.primary, const Color(0xFF8E4B4B));
    expect(scheme.primary, AppColors.primary);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.cardTheme.color, AppColors.surface);
  });

  test('các cặp chữ và nền đạt tương phản tối thiểu 4.5', () {
    final pairs = <String, List<Color>>{
      'chữ trắng trên nút chính': [scheme.onPrimary, scheme.primary],
      'chữ trên nút phụ': [
        scheme.onSecondaryContainer,
        scheme.secondaryContainer,
      ],
      'chữ chính trên nền': [scheme.onSurface, scheme.surface],
      'chữ phụ trên nền': [scheme.onSurfaceVariant, scheme.surface],
      'chữ trên thanh dưới': [scheme.onSurface, scheme.surfaceContainerHighest],
      'chữ trắng trên nút nguy hiểm': [scheme.onError, scheme.error],
      'chữ trắng trên dải quản trị': [Colors.white, AppColors.info],
      'lỗi trên nền': [scheme.error, scheme.surface],
      'cảnh báo trên nền': [AppColors.warning, AppColors.background],
      'thành công trên nền': [AppColors.success, AppColors.background],
    };
    pairs.forEach((name, colors) {
      expect(
        _contrast(colors[0], colors[1]),
        greaterThanOrEqualTo(4.5),
        reason: name,
      );
    });
  });

  test('nút cao tối thiểu 56 và bo góc 14', () {
    final filled = theme.filledButtonTheme.style!;
    final outlined = theme.outlinedButtonTheme.style!;
    expect(filled.minimumSize!.resolve(<WidgetState>{})!.height, 56);
    expect(outlined.minimumSize!.resolve(<WidgetState>{})!.height, 56);
    final shape =
        filled.shape!.resolve(<WidgetState>{}) as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(14));
  });

  test('card bo góc 16', () {
    final shape = theme.cardTheme.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(16));
  });

  test('chữ nội dung đủ lớn cho người lớn tuổi', () {
    expect(theme.textTheme.bodyLarge!.fontSize, 18);
    expect(theme.textTheme.bodyMedium!.fontSize, 17);
  });

  testWidgets('FilledButton trong app cao 56', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: FilledButton(onPressed: () {}, child: const Text('Thử')),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(FilledButton)).height, 56);
  });
}
