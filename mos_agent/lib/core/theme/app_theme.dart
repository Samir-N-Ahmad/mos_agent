import 'package:flutter/material.dart';

abstract final class AppTheme {
  static final dark = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF96B6FF),
      brightness: Brightness.dark,
      surface: const Color(0xFF101216),
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 350),
    ),
  );
}
