import 'package:flutter/material.dart';

/// Central place for the game's visual identity: gem palettes, background
/// gradients and reusable text styles. Keeping it here makes the whole game
/// easy to re-skin.
class GameTheme {
  static const Color bgTop = Color(0xFF1A0B3B);
  static const Color bgMid = Color(0xFF2D1B69);
  static const Color bgBottom = Color(0xFF0F0524);

  static const LinearGradient background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgTop, bgMid, bgBottom],
  );

  static const Color boardBg = Color(0x33FFFFFF);
  static const Color boardBorder = Color(0x55FFFFFF);

  static const Color accent = Color(0xFFFFD54F);
  static const Color textLight = Color(0xFFF5F3FF);
  static const Color textDim = Color(0xFFB9AEE0);

  /// Two-tone gradient per gem type, used by the custom painter to give each
  /// gem depth and a jewel-like sheen.
  static const List<List<Color>> gemGradients = [
    [Color(0xFFFF6B6B), Color(0xFFC0392B)], // 0 ruby
    [Color(0xFF4FC3F7), Color(0xFF1565C0)], // 1 sapphire
    [Color(0xFF81C784), Color(0xFF2E7D32)], // 2 emerald
    [Color(0xFFFFD54F), Color(0xFFF9A825)], // 3 topaz
    [Color(0xFFBA68C8), Color(0xFF6A1B9A)], // 4 amethyst
    [Color(0xFFFF8A65), Color(0xFFE64A19)], // 5 amber
  ];

  static const List<Color> gemGlow = [
    Color(0xFFFF6B6B),
    Color(0xFF4FC3F7),
    Color(0xFF81C784),
    Color(0xFFFFD54F),
    Color(0xFFBA68C8),
    Color(0xFFFF8A65),
  ];

  static TextStyle title = const TextStyle(
    fontSize: 44,
    fontWeight: FontWeight.w900,
    color: textLight,
    letterSpacing: 2,
    shadows: [
      Shadow(color: Color(0xFF7C4DFF), blurRadius: 24, offset: Offset(0, 4)),
    ],
  );

  static const TextStyle hudLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: textDim,
    letterSpacing: 1.2,
  );

  static const TextStyle hudValue = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: textLight,
  );
}
