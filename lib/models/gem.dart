import 'package:flutter/material.dart';

/// The distinct gem types on the board. Each has its own color scheme and
/// icon so the board reads clearly even for color-blind players.
enum GemType { ruby, sapphire, emerald, amber, amethyst, topaz }

extension GemTypeVisuals on GemType {
  /// Gradient colors used to paint the gem (top-left -> bottom-right).
  List<Color> get gradient {
    switch (this) {
      case GemType.ruby:
        return const [Color(0xFFFF6B6B), Color(0xFFC0392B)];
      case GemType.sapphire:
        return const [Color(0xFF5DADE2), Color(0xFF2471A3)];
      case GemType.emerald:
        return const [Color(0xFF58D68D), Color(0xFF1E8449)];
      case GemType.amber:
        return const [Color(0xFFF7DC6F), Color(0xFFD68910)];
      case GemType.amethyst:
        return const [Color(0xFFBB8FCE), Color(0xFF7D3C98)];
      case GemType.topaz:
        return const [Color(0xFF48C9B0), Color(0xFF148F77)];
    }
  }

  /// A distinguishing glyph, helps accessibility and adds character.
  IconData get icon {
    switch (this) {
      case GemType.ruby:
        return Icons.favorite;
      case GemType.sapphire:
        return Icons.water_drop;
      case GemType.emerald:
        return Icons.eco;
      case GemType.amber:
        return Icons.star;
      case GemType.amethyst:
        return Icons.auto_awesome;
      case GemType.topaz:
        return Icons.hexagon;
    }
  }

  Color get glowColor => gradient.first;
}

/// Special powers a gem can gain from bigger matches.
enum GemPower {
  none,

  /// Created from a match of 4 - clears its whole row or column when matched.
  rocket,

  /// Created from a match of 5+ - clears all gems of the chosen type.
  bomb,
}

/// A single gem on the board. Carries a stable [id] so the UI can animate a
/// gem moving/falling rather than treating every rebuild as a new widget.
class Gem {
  Gem({
    required this.id,
    required this.type,
    this.power = GemPower.none,
  });

  final int id;
  GemType type;
  GemPower power;

  Gem copyWith({GemType? type, GemPower? power}) =>
      Gem(id: id, type: type ?? this.type, power: power ?? this.power);

  @override
  String toString() => 'Gem($id, $type, $power)';
}
