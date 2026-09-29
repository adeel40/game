import 'package:flutter/material.dart';

/// Central palette + theme so screens share a consistent, polished look.
class AppTheme {
  static const Color bgTop = Color(0xFF1A1035);
  static const Color bgBottom = Color(0xFF2D1B4E);
  static const Color accent = Color(0xFFFFD166);
  static const Color panel = Color(0x33FFFFFF);

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7D3C98),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: bgTop,
      );

  static const LinearGradient background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgTop, bgBottom],
  );

  static const LinearGradient accentButton = LinearGradient(
    colors: [Color(0xFFFFD166), Color(0xFFEF8354)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
