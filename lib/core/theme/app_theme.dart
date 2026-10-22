import 'package:flutter/material.dart';

class AppTheme {
  static const _seed = Color(0xFF8B1E1E); // đỏ đậm, hợp tông gia phả

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: _seed),
      appBarTheme: const AppBarTheme(centerTitle: true),
    );
  }
}