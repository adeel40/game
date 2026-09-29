import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/level.dart';
import 'board.dart';

enum GameStatus { playing, won, lost }

/// Owns the live game state for one level and exposes it to the UI. The widget
/// layer listens for changes and plays animations off the emitted resolve
/// steps; this class never touches Flutter widgets directly.
class GameController extends ChangeNotifier {
  GameController(this.level)
      : board = Board(
          rows: level.rows,
          cols: level.cols,
          gemTypeCount: level.gemTypes,
        ) {
    movesLeft = level.moves;
  }

  final Level level;
  final Board board;

  int score = 0;
  late int movesLeft;
  GameStatus status = GameStatus.playing;
  bool busy = false; // true while a resolve animation is playing

  int get stars => level.starsForScore(score);
  double get targetProgress =>
      (score / level.targetScore).clamp(0.0, 1.0).toDouble();

  /// Validate + apply a player swap, spending one move. Returns true if the
  /// swap was legal (created a match) and the board should now be resolved via
  /// [clearStep]/[collapseStep]. Returns false for illegal swaps (board left
  /// untouched).
  bool applyPlayerSwap(Pos a, Pos b) {
    if (busy || status != GameStatus.playing) return false;
    if (!board.isValidSwap(a, b)) return false;
    board.applySwap(a, b);
    movesLeft--;
    notifyListeners();
    return true;
  }

  /// Clear the current matches (one cascade layer) and add their score.
  /// Returns the step for the UI to animate, or null when the board is stable.
  ResolveStep? clearStep(int cascadeLevel) {
    final step = board.clearMatches(cascadeLevel: cascadeLevel);
    if (step != null) {
      score += step.gained;
      notifyListeners();
    }
    return step;
  }

  /// Collapse gems down and refill after a clear. Returns the movements.
  List<GemMove> collapseStep() {
    final moves = board.collapseAndRefill();
    notifyListeners();
    return moves;
  }

  /// Called once a swap's full cascade chain has finished: guard against
  /// deadlocks and evaluate win/lose.
  void finishTurn() {
    if (!board.hasAvailableMove()) {
      board.reshuffle();
    }
    _evaluateEnd();
    notifyListeners();
  }

  void _evaluateEnd() {
    // The level runs until moves are exhausted, so players can keep scoring
    // past the target to chase a 2- or 3-star rating. You win if you met the
    // target by the time moves run out, otherwise you lose.
    if (movesLeft <= 0) {
      status =
          score >= level.targetScore ? GameStatus.won : GameStatus.lost;
    }
  }

  void setBusy(bool value) {
    busy = value;
    notifyListeners();
  }

  // ---- Persistence of progress & high scores ----

  static const _kUnlockedKey = 'unlocked_level';
  static const _kStarsPrefix = 'stars_level_';
  static const _kBestPrefix = 'best_level_';

  static Future<int> unlockedLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kUnlockedKey) ?? 1;
  }

  static Future<int> starsFor(int levelNumber) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_kStarsPrefix$levelNumber') ?? 0;
  }

  static Future<int> bestScoreFor(int levelNumber) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_kBestPrefix$levelNumber') ?? 0;
  }

  /// Persist the outcome of a won level: unlock the next one and store the
  /// best star count and score.
  Future<void> saveProgress() async {
    if (status != GameStatus.won) return;
    final prefs = await SharedPreferences.getInstance();

    final prevStars = prefs.getInt('$_kStarsPrefix${level.number}') ?? 0;
    if (stars > prevStars) {
      await prefs.setInt('$_kStarsPrefix${level.number}', stars);
    }
    final prevBest = prefs.getInt('$_kBestPrefix${level.number}') ?? 0;
    if (score > prevBest) {
      await prefs.setInt('$_kBestPrefix${level.number}', score);
    }
    final unlocked = prefs.getInt(_kUnlockedKey) ?? 1;
    final next = (level.number + 1).clamp(1, Levels.total);
    if (next > unlocked) {
      await prefs.setInt(_kUnlockedKey, next);
    }
  }
}
