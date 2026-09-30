/// Objective-based level definitions. Each level gives the player a limited
/// number of moves to reach a target score. Later levels are tighter, and some
/// restrict the number of gem colours to make matches (and thus power-ups)
/// harder to line up.
class LevelDef {
  const LevelDef({
    required this.index,
    required this.moves,
    required this.targetScore,
    required this.gemTypes,
    required this.name,
  });

  final int index; // 0-based
  final int moves;
  final int targetScore;
  final int gemTypes; // number of distinct gem colours in play (<= 6)
  final String name;

  int get displayNumber => index + 1;
}

class Levels {
  static const List<LevelDef> all = [
    LevelDef(index: 0, moves: 25, targetScore: 800, gemTypes: 5, name: 'Sunrise'),
    LevelDef(index: 1, moves: 24, targetScore: 1400, gemTypes: 5, name: 'Meadow'),
    LevelDef(index: 2, moves: 22, targetScore: 2000, gemTypes: 6, name: 'Cavern'),
    LevelDef(index: 3, moves: 22, targetScore: 2800, gemTypes: 6, name: 'Tide'),
    LevelDef(index: 4, moves: 20, targetScore: 3600, gemTypes: 6, name: 'Ember'),
    LevelDef(index: 5, moves: 20, targetScore: 4600, gemTypes: 6, name: 'Storm'),
    LevelDef(index: 6, moves: 18, targetScore: 5800, gemTypes: 6, name: 'Frost'),
    LevelDef(index: 7, moves: 18, targetScore: 7200, gemTypes: 6, name: 'Nova'),
    LevelDef(index: 8, moves: 16, targetScore: 9000, gemTypes: 6, name: 'Eclipse'),
    LevelDef(index: 9, moves: 16, targetScore: 12000, gemTypes: 6, name: 'Cosmos'),
  ];

  static int get count => all.length;

  static LevelDef byIndex(int i) => all[i.clamp(0, all.length - 1)];
}
