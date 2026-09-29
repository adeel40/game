import 'package:flutter_test/flutter_test.dart';
import 'package:gem_crush/game/board.dart';
import 'package:gem_crush/models/level.dart';

void main() {
  group('Board generation', () {
    test('starts with no matches and at least one available move', () {
      for (var seed = 0; seed < 50; seed++) {
        final board = Board(rows: 8, cols: 8, gemTypeCount: 5, seed: seed);
        expect(board.hasAvailableMove(), isTrue,
            reason: 'seed $seed should have a move');
        // No pre-existing 3-in-a-rows.
        expect(_hasAnyRunOfThree(board), isFalse,
            reason: 'seed $seed should have no starting match');
      }
    });
  });

  group('Swaps', () {
    test('rejects non-adjacent swaps', () {
      final board = Board(rows: 8, cols: 8, gemTypeCount: 5, seed: 1);
      expect(board.isValidSwap(const Pos(0, 0), const Pos(2, 2)), isFalse);
    });

    test('a valid swap resolves into at least one cascade step', () {
      // Find any valid move on a seeded board and confirm it clears gems.
      final board = Board(rows: 8, cols: 8, gemTypeCount: 5, seed: 3);
      Pos? a, b;
      outer:
      for (var r = 0; r < board.rows; r++) {
        for (var c = 0; c < board.cols; c++) {
          for (final d in const [Pos(0, 1), Pos(1, 0)]) {
            final t = Pos(r + d.row, c + d.col);
            if (board.inBounds(t) && board.isValidSwap(Pos(r, c), t)) {
              a = Pos(r, c);
              b = t;
              break outer;
            }
          }
        }
      }
      expect(a, isNotNull);
      board.applySwap(a!, b!);
      final steps = board.resolve();
      expect(steps, isNotEmpty);
      expect(steps.first.cleared.length, greaterThanOrEqualTo(3));
      expect(steps.first.gained, greaterThan(0));
    });

    test('board never left in a deadlock after resolve+reshuffle', () {
      final board = Board(rows: 7, cols: 7, gemTypeCount: 4, seed: 9);
      board.resolve();
      if (!board.hasAvailableMove()) board.reshuffle();
      expect(board.hasAvailableMove(), isTrue);
    });
  });

  group('Levels', () {
    test('difficulty ramps: later levels have higher targets', () {
      expect(Levels.get(10).targetScore, greaterThan(Levels.get(1).targetScore));
    });

    test('star thresholds are monotonic', () {
      final l = Levels.get(1);
      expect(l.starsForScore(0), 0);
      expect(l.starsForScore(l.targetScore), greaterThanOrEqualTo(1));
      expect(l.starsForScore(l.targetScore * 3), 3);
    });
  });
}

bool _hasAnyRunOfThree(Board board) {
  for (var r = 0; r < board.rows; r++) {
    for (var c = 0; c < board.cols - 2; c++) {
      final t = board.grid[r][c].type;
      if (board.grid[r][c + 1].type == t && board.grid[r][c + 2].type == t) {
        return true;
      }
    }
  }
  for (var c = 0; c < board.cols; c++) {
    for (var r = 0; r < board.rows - 2; r++) {
      final t = board.grid[r][c].type;
      if (board.grid[r + 1][c].type == t && board.grid[r + 2][c].type == t) {
        return true;
      }
    }
  }
  return false;
}
