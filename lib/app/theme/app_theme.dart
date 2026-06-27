import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const accentBlue = Color(0xFF2F80ED);
  static const lightBackground = Color(0xFFF6F7F9);
  static const darkBackground = Color(0xFF0B0C0E);
  static const lightSurface = Color(0xFFFFFFFF);
  static const darkSurface = Color(0xFF181A1F);
  static const quietLineLight = Color(0xFFE4E7EC);
  static const quietLineDark = Color(0xFF2A2D34);

  static ThemeData get light {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: accentBlue,
          brightness: Brightness.light,
        ).copyWith(
          primary: accentBlue,
          surface: lightSurface,
          onSurface: const Color(0xFF111318),
          onSurfaceVariant: const Color(0xFF69707A),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: lightBackground,
      dividerColor: quietLineLight,
      textTheme: _textTheme(colorScheme.onSurface),
    );
  }

  static ThemeData get dark {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: accentBlue,
          brightness: Brightness.dark,
        ).copyWith(
          primary: accentBlue,
          surface: darkSurface,
          onSurface: const Color(0xFFF5F6F8),
          onSurfaceVariant: const Color(0xFFA5ABB4),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkBackground,
      dividerColor: quietLineDark,
      textTheme: _textTheme(colorScheme.onSurface),
    );
  }

  static CupertinoThemeData cupertinoThemeFor(ThemeData theme) {
    return CupertinoThemeData(
      brightness: theme.brightness,
      primaryColor: accentBlue,
      scaffoldBackgroundColor: theme.scaffoldBackgroundColor,
      barBackgroundColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.92),
      textTheme: CupertinoTextThemeData(
        textStyle: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 17,
          letterSpacing: 0,
        ),
        navTitleTextStyle: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }

  static TextTheme _textTheme(Color textColor) {
    return TextTheme(
      headlineLarge: TextStyle(
        color: textColor,
        fontSize: 56,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      titleLarge: TextStyle(
        color: textColor,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      titleMedium: TextStyle(
        color: textColor,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      bodyLarge: TextStyle(
        color: textColor,
        fontSize: 17,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
      bodyMedium: TextStyle(
        color: textColor,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
      labelMedium: TextStyle(
        color: textColor,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
    );
  }
}
