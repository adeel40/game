/// Definition of a single playable level. Levels ramp up difficulty by
/// tightening the move budget and raising the target score.
class Level {
  const Level({
    required this.number,
    required this.rows,
    required this.cols,
    required this.moves,
    required this.targetScore,
    required this.gemTypes,
  });

  final int number;
  final int rows;
  final int cols;
  final int moves;
  final int targetScore;

  /// How many distinct gem types are in play. Fewer types = easier matches.
  final int gemTypes;

  /// Star thresholds: 1 star at target, 2 stars at 1.5x, 3 stars at 2.5x.
  int starsForScore(int score) {
    if (score >= targetScore * 2.5) return 3;
    if (score >= targetScore * 1.5) return 2;
    if (score >= targetScore) return 1;
    return 0;
  }
}

/// Procedurally generated level list so the game never "runs out". Early
/// levels are gentle; later ones add gem types and cut down on moves.
class Levels {
  static const int total = 30;

  static Level get(int number) {
    final n = number.clamp(1, total);
    final gemTypes = (4 + (n ~/ 6)).clamp(4, 6);
    final moves = (28 - (n ~/ 3)).clamp(15, 28);
    final targetScore = 1500 + (n - 1) * 900;
    final size = n < 4 ? 7 : 8;
    return Level(
      number: n,
      rows: size,
      cols: size,
      moves: moves,
      targetScore: targetScore,
      gemTypes: gemTypes,
    );
  }
}
