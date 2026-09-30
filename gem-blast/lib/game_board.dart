import 'dart:math';

/// Pure game-logic for a Match-3 board. It knows nothing about Flutter/UI so
/// it is easy to reason about and could be unit tested independently.
///
/// Cells hold an int gem type in [0, gemTypes). A value of -1 means "empty"
/// (used transiently while resolving cascades before refill).
class GameBoard {
  GameBoard({this.rows = 8, this.cols = 8, this.gemTypes = 6, int? seed})
    : _rng = Random(seed) {
    _fillInitial();
  }

  final int rows;
  final int cols;
  final int gemTypes;
  final Random _rng;

  late List<List<int>> grid;

  int _randomGem() => _rng.nextInt(gemTypes);

  /// Build a starting board that contains no pre-existing matches so the
  /// player always begins from a stable position.
  void _fillInitial() {
    grid = List.generate(rows, (_) => List.filled(cols, -1));
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        int gem;
        do {
          gem = _randomGem();
        } while (_wouldMatchAt(r, c, gem));
        grid[r][c] = gem;
      }
    }
  }

  bool _wouldMatchAt(int r, int c, int gem) {
    // Horizontal: two to the left already equal to gem.
    if (c >= 2 && grid[r][c - 1] == gem && grid[r][c - 2] == gem) return true;
    // Vertical: two above already equal to gem.
    if (r >= 2 && grid[r - 1][c] == gem && grid[r - 2][c] == gem) return true;
    return false;
  }

  bool inBounds(int r, int c) => r >= 0 && r < rows && c >= 0 && c < cols;

  bool areAdjacent(Point<int> a, Point<int> b) {
    final dr = (a.x - b.x).abs();
    final dc = (a.y - b.y).abs();
    return (dr + dc) == 1;
  }

  void _swap(Point<int> a, Point<int> b) {
    final tmp = grid[a.x][a.y];
    grid[a.x][a.y] = grid[b.x][b.y];
    grid[b.x][b.y] = tmp;
  }

  /// Returns true if swapping a and b produces at least one match.
  bool wouldSwapMatch(Point<int> a, Point<int> b) {
    _swap(a, b);
    final has = findMatches().isNotEmpty;
    _swap(a, b); // revert
    return has;
  }

  /// Perform a swap unconditionally (caller is expected to have validated it,
  /// or wants to animate the invalid swap-back).
  void applySwap(Point<int> a, Point<int> b) => _swap(a, b);

  /// Find every cell that is part of a horizontal or vertical run of 3+.
  Set<Point<int>> findMatches() {
    final matched = <Point<int>>{};

    // Horizontal runs.
    for (int r = 0; r < rows; r++) {
      int runStart = 0;
      for (int c = 1; c <= cols; c++) {
        final same = c < cols && grid[r][c] != -1 && grid[r][c] == grid[r][runStart];
        if (!same) {
          if (c - runStart >= 3) {
            for (int k = runStart; k < c; k++) {
              matched.add(Point(r, k));
            }
          }
          runStart = c;
        }
      }
    }

    // Vertical runs.
    for (int c = 0; c < cols; c++) {
      int runStart = 0;
      for (int r = 1; r <= rows; r++) {
        final same = r < rows && grid[r][c] != -1 && grid[r][c] == grid[runStart][c];
        if (!same) {
          if (r - runStart >= 3) {
            for (int k = runStart; k < r; k++) {
              matched.add(Point(k, c));
            }
          }
          runStart = r;
        }
      }
    }

    return matched;
  }

  /// Clear matched cells to empty (-1).
  void clearCells(Set<Point<int>> cells) {
    for (final p in cells) {
      grid[p.x][p.y] = -1;
    }
  }

  /// Apply gravity: gems fall to fill empty cells beneath them.
  /// Returns a map of destination cell -> number of rows it fell (used to
  /// drive fall animations in the UI).
  Map<Point<int>, int> applyGravity() {
    final fell = <Point<int>, int>{};
    for (int c = 0; c < cols; c++) {
      int writeRow = rows - 1;
      for (int r = rows - 1; r >= 0; r--) {
        if (grid[r][c] != -1) {
          if (writeRow != r) {
            grid[writeRow][c] = grid[r][c];
            grid[r][c] = -1;
            fell[Point(writeRow, c)] = writeRow - r;
          }
          writeRow--;
        }
      }
    }
    return fell;
  }

  /// Fill the empty cells at the top with new random gems.
  /// Returns the newly-created cells so the UI can animate them dropping in.
  Set<Point<int>> refill() {
    final created = <Point<int>>{};
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows; r++) {
        if (grid[r][c] == -1) {
          grid[r][c] = _randomGem();
          created.add(Point(r, c));
        }
      }
    }
    return created;
  }

  /// Is there any legal move left? Used to detect a "no moves" shuffle.
  bool hasPossibleMove() {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (c + 1 < cols && wouldSwapMatch(Point(r, c), Point(r, c + 1))) {
          return true;
        }
        if (r + 1 < rows && wouldSwapMatch(Point(r, c), Point(r + 1, c))) {
          return true;
        }
      }
    }
    return false;
  }

  /// Reshuffle all gems in place until at least one move exists and there are
  /// no immediate matches.
  void reshuffle() {
    final flat = <int>[];
    for (final row in grid) {
      flat.addAll(row);
    }
    do {
      flat.shuffle(_rng);
      int i = 0;
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          grid[r][c] = flat[i++];
        }
      }
    } while (findMatches().isNotEmpty || !hasPossibleMove());
  }
}
