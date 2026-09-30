import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:gem_blast/game_board.dart';

void main() {
  test('initial board has no pre-existing matches', () {
    final b = GameBoard(seed: 42);
    expect(b.findMatches(), isEmpty);
  });

  test('initial board always has at least one possible move', () {
    for (int s = 0; s < 20; s++) {
      final b = GameBoard(seed: s);
      expect(b.hasPossibleMove(), isTrue, reason: 'seed $s had no moves');
    }
  });

  test('gravity pulls gems down into empty cells', () {
    final b = GameBoard(rows: 3, cols: 1, seed: 1);
    b.grid = [
      [0],
      [-1],
      [-1],
    ];
    b.applyGravity();
    expect(b.grid[2][0], 0);
    expect(b.grid[0][0], -1);
  });

  test('refill fills every empty cell', () {
    final b = GameBoard(rows: 4, cols: 4, seed: 3);
    b.clearCells({for (int c = 0; c < 4; c++) Point(0, c)});
    b.applyGravity();
    final created = b.refill();
    expect(created, isNotEmpty);
    for (final row in b.grid) {
      for (final v in row) {
        expect(v, isNot(-1));
      }
    }
  });

  test('a valid swap is detected as producing a match', () {
    final b = GameBoard(rows: 3, cols: 3, seed: 9);
    // Craft a board where swapping (2,2)<->(2,0) is irrelevant; instead set up
    // a clear horizontal near-match on the top row.
    b.grid = [
      [1, 1, 2],
      [3, 4, 1],
      [5, 0, 4],
    ];
    // Swapping (0,2)=2 with (1,2)=1 makes row0 -> 1,1,1 (match).
    expect(b.wouldSwapMatch(const Point(0, 2), const Point(1, 2)), isTrue);
  });
}
