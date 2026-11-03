import 'package:flutter/material.dart';

abstract final class AppTheme {
  static final dark = _theme(Brightness.dark);
  static final light = _theme(Brightness.light);

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colors =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF737373),
          brightness: brightness,
        ).copyWith(
          surface: Color(dark ? 0xFF000000 : 0xFFFFFFFF),
          surfaceContainerLow: Color(dark ? 0xFF151517 : 0xFFE5E7EB),
          surfaceContainer: Color(dark ? 0xFF1C1C1E : 0xFFF8FAFC),
          surfaceContainerHigh: Color(dark ? 0xFF242426 : 0xFFF5F5F7),
          surfaceContainerHighest: Color(dark ? 0xFF2C2C2E : 0xFFEDEDEF),
          onSurface: Color(dark ? 0xFFF5F5F7 : 0xFF171717),
          onSurfaceVariant: Color(dark ? 0xFFA1A1A6 : 0xFF737373),
          primary: Color(dark ? 0xFFF5F5F7 : 0xFF171717),
          onPrimary: Color(dark ? 0xFF171717 : 0xFFF5F5F7),
          secondaryContainer: Color(dark ? 0xFF2C2C2E : 0xFFEDEDEF),
          onSecondaryContainer: Color(dark ? 0xFFF5F5F7 : 0xFF171717),
          outlineVariant: Color(dark ? 0xFF38383A : 0xFFE2E2E7),
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w600,
          color: colors.onSurface,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: colors.onSurface,
        ),
        titleMedium: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: colors.onSurface,
        ),
        titleSmall: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: colors.onSurface,
        ),
        bodyLarge: TextStyle(
          fontSize: 17,
          height: 1.6,
          color: colors.onSurface,
        ),
        bodyMedium: TextStyle(fontSize: 16, color: colors.onSurface),
        bodySmall: TextStyle(
          fontSize: 13,
          height: 1.4,
          color: colors.onSurfaceVariant,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: colors.onSurface,
        ),
        labelMedium: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        labelSmall: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
      ),
      dividerColor: colors.outlineVariant,
      iconTheme: IconThemeData(color: colors.onSurface, size: 22),
      tooltipTheme: const TooltipThemeData(
        waitDuration: Duration(milliseconds: 350),
      ),
    );
  }
}
