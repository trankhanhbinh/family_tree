import 'package:flutter/material.dart';

import 'package:familytree/core/theme/app_colors.dart';

class AppTheme {
  static const ColorScheme _scheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.softRose,
    onPrimaryContainer: AppColors.primaryDark,
    secondary: AppColors.primaryDark,
    onSecondary: Colors.white,
    secondaryContainer: AppColors.softRose,
    onSecondaryContainer: AppColors.primaryDark,
    tertiary: AppColors.info,
    onTertiary: Colors.white,
    error: AppColors.error,
    onError: Colors.white,
    errorContainer: Color(0xFFF9DEDC),
    onErrorContainer: Color(0xFF410E0B),
    surface: AppColors.background,
    onSurface: AppColors.text,
    onSurfaceVariant: Color(0xFF5C524E),
    outline: Color(0xFF857571),
    outlineVariant: Color(0xFFE3D6D2),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFF3A3230),
    onInverseSurface: Color(0xFFF7EFEC),
    inversePrimary: Color(0xFFE5B5B5),
    surfaceTint: Colors.transparent,
    surfaceContainerLowest: AppColors.surface,
    surfaceContainerLow: AppColors.surface,
    surfaceContainer: Color(0xFFF7F1EE),
    surfaceContainerHigh: Color(0xFFF3ECE9),
    surfaceContainerHighest: AppColors.softRose,
  );

  static ThemeData light() {
    final baseText = ThemeData(
      useMaterial3: true,
      colorScheme: _scheme,
    ).textTheme.apply(bodyColor: AppColors.text, displayColor: AppColors.text);
    final textTheme = baseText.copyWith(
      bodyLarge: baseText.bodyLarge?.copyWith(fontSize: 18),
      bodyMedium: baseText.bodyMedium?.copyWith(fontSize: 17),
      bodySmall: baseText.bodySmall?.copyWith(fontSize: 15),
    );

    const buttonTextStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
    );
    const buttonPadding = EdgeInsets.symmetric(horizontal: 20);
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: _scheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 56),
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonTextStyle,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 56),
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonTextStyle,
          backgroundColor: AppColors.softRose,
          foregroundColor: AppColors.primaryDark,
          side: BorderSide.none,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonTextStyle,
          foregroundColor: AppColors.primary,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      dividerTheme: DividerThemeData(color: _scheme.outlineVariant),
    );
  }
}
