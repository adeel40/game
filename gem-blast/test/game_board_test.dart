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
      [Cell(0)],
      [Cell(-1)],
      [Cell(-1)],
    ];
    b.applyGravity();
    expect(b.grid[2][0].type, 0);
    expect(b.grid[0][0].isEmpty, isTrue);
  });

  test('refill fills every empty cell', () {
    final b = GameBoard(rows: 4, cols: 4, seed: 3);
    for (int c = 0; c < 4; c++) {
      b.grid[0][c] = Cell(-1);
    }
    b.applyGravity();
    final created = b.refill();
    expect(created, isNotEmpty);
    for (final row in b.grid) {
      for (final cell in row) {
        expect(cell.isEmpty, isFalse);
      }
    }
  });

  test('a valid swap is detected as producing a match', () {
    final b = GameBoard(rows: 3, cols: 3, seed: 9);
    b.grid = [
      [Cell(1), Cell(1), Cell(2)],
      [Cell(3), Cell(4), Cell(1)],
      [Cell(5 % 6), Cell(0), Cell(4)],
    ];
    // Swapping (0,2)=2 with (1,2)=1 makes row0 -> 1,1,1.
    expect(b.wouldSwapMatch(const Point(0, 2), const Point(1, 2)), isTrue);
  });

  test('a match of 4 creates a line-blast power-up', () {
    final b = GameBoard(rows: 3, cols: 5, gemTypes: 6, seed: 1);
    // Row 0: four 2s in a row already present.
    b.grid = [
      [Cell(2), Cell(2), Cell(2), Cell(2), Cell(0)],
      [Cell(1), Cell(3), Cell(4), Cell(5), Cell(1)],
      [Cell(3), Cell(4), Cell(5), Cell(1), Cell(2)],
    ];
    final result = b.resolveClearStep();
    expect(result.cleared.length, greaterThanOrEqualTo(4));
    expect(result.createdSpecials.values, contains(Special.rowBlast));
  });

  test('a match of 5 creates a color-clear power-up', () {
    final b = GameBoard(rows: 2, cols: 5, gemTypes: 6, seed: 1);
    b.grid = [
      [Cell(2), Cell(2), Cell(2), Cell(2), Cell(2)],
      [Cell(1), Cell(3), Cell(4), Cell(5), Cell(1)],
    ];
    final result = b.resolveClearStep();
    expect(result.createdSpecials.values, contains(Special.colorClear));
  });

  test('detonating a row-blast clears the whole row', () {
    final b = GameBoard(rows: 3, cols: 4, gemTypes: 6, seed: 2);
    b.grid[1][1] = Cell(0, Special.rowBlast);
    final cleared = b.detonate(const Point(1, 1));
    for (int c = 0; c < 4; c++) {
      expect(cleared.contains(Point(1, c)), isTrue);
    }
  });

  test('detonating a bomb clears a 3x3 area', () {
    final b = GameBoard(rows: 5, cols: 5, gemTypes: 6, seed: 2);
    b.grid[2][2] = Cell(0, Special.bomb);
    final cleared = b.detonate(const Point(2, 2));
    expect(cleared.length, 9);
  });
}
