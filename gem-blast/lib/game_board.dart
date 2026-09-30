import 'dart:math';

/// Kinds of special "power-up" gems a match can create.
enum Special {
  none, // ordinary gem
  rowBlast, // clears its entire row
  colBlast, // clears its entire column
  bomb, // clears a 3x3 area
  colorClear, // clears every gem of a chosen colour
}

/// A single board cell: a colour [type] in [0, gemTypes) plus an optional
/// [special] power. type == -1 means empty (transient during cascades).
class Cell {
  Cell(this.type, [this.special = Special.none]);
  int type;
  Special special;

  bool get isEmpty => type == -1;
  bool get isSpecial => special != Special.none;

  Cell copy() => Cell(type, special);
}

/// Result of clearing matches on the board — used by the UI for scoring,
/// effects and sound.
class ClearResult {
  ClearResult(this.cleared, this.createdSpecials, this.triggeredSpecials);

  /// All cells that were removed this step.
  final Set<Point<int>> cleared;

  /// New power-up gems created by 4+/L/T matches: position -> special.
  final Map<Point<int>, Special> createdSpecials;

  /// Whether any special gem detonated this step (for sound/haptics).
  final bool triggeredSpecials;
}

/// Pure Match-3 logic with power-up gems. No Flutter dependency.
class GameBoard {
  GameBoard({this.rows = 8, this.cols = 8, this.gemTypes = 6, int? seed})
    : _rng = Random(seed) {
    _fillInitial();
  }

  final int rows;
  final int cols;
  final int gemTypes;
  final Random _rng;

  late List<List<Cell>> grid;

  int _randomGem() => _rng.nextInt(gemTypes);

  void _fillInitial() {
    grid = List.generate(rows, (_) => List.generate(cols, (_) => Cell(-1)));
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        int gem;
        do {
          gem = _randomGem();
        } while (_wouldMatchAt(r, c, gem));
        grid[r][c] = Cell(gem);
      }
    }
  }

  bool _wouldMatchAt(int r, int c, int gem) {
    if (c >= 2 && grid[r][c - 1].type == gem && grid[r][c - 2].type == gem) {
      return true;
    }
    if (r >= 2 && grid[r - 1][c].type == gem && grid[r - 2][c].type == gem) {
      return true;
    }
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

  /// A swap is valid if it makes a match, OR if either gem is a special (which
  /// can always be activated by swapping).
  bool wouldSwapMatch(Point<int> a, Point<int> b) {
    if (grid[a.x][a.y].isSpecial || grid[b.x][b.y].isSpecial) return true;
    _swap(a, b);
    final has = _findRuns().isNotEmpty;
    _swap(a, b);
    return has;
  }

  void applySwap(Point<int> a, Point<int> b) => _swap(a, b);

  /// Raw run detection: returns groups of collinear 3+ same-colour cells.
  List<List<Point<int>>> _findRuns() {
    final runs = <List<Point<int>>>[];

    for (int r = 0; r < rows; r++) {
      int start = 0;
      for (int c = 1; c <= cols; c++) {
        final same = c < cols &&
            !grid[r][c].isEmpty &&
            grid[r][c].type == grid[r][start].type;
        if (!same) {
          if (c - start >= 3) {
            runs.add([for (int k = start; k < c; k++) Point(r, k)]);
          }
          start = c;
        }
      }
    }
    for (int c = 0; c < cols; c++) {
      int start = 0;
      for (int r = 1; r <= rows; r++) {
        final same = r < rows &&
            !grid[r][c].isEmpty &&
            grid[r][c].type == grid[start][c].type;
        if (!same) {
          if (r - start >= 3) {
            runs.add([for (int k = start; k < r; k++) Point(k, c)]);
          }
          start = r;
        }
      }
    }
    return runs;
  }

  /// Flattened set of every currently matched cell (used for move detection).
  Set<Point<int>> findMatches() {
    final s = <Point<int>>{};
    for (final run in _findRuns()) {
      s.addAll(run);
    }
    return s;
  }

  /// Resolve one clear step. Detects runs, decides which power-ups to create
  /// (based on run length / intersection), expands any specials that were part
  /// of a match, and clears the affected cells.
  ///
  /// [swappedInto] is the cell the player moved a gem into; a newly created
  /// power-up prefers to appear there for a satisfying feel.
  ClearResult resolveClearStep({Point<int>? swappedInto}) {
    final runs = _findRuns();
    if (runs.isEmpty) {
      return ClearResult({}, {}, false);
    }

    final toClear = <Point<int>>{};
    final created = <Point<int>, Special>{};

    // Group overlapping runs so an L/T shape counts once for a bomb.
    final cellToRuns = <Point<int>, List<int>>{};
    for (int i = 0; i < runs.length; i++) {
      for (final p in runs[i]) {
        cellToRuns.putIfAbsent(p, () => []).add(i);
      }
    }

    for (int i = 0; i < runs.length; i++) {
      final run = runs[i];
      toClear.addAll(run);

      final isHorizontal = run.first.x == run.last.x;
      final intersects = run.any((p) => (cellToRuns[p]?.length ?? 0) > 1);

      Special? make;
      if (run.length >= 5) {
        make = Special.colorClear;
      } else if (intersects) {
        make = Special.bomb;
      } else if (run.length == 4) {
        make = isHorizontal ? Special.rowBlast : Special.colBlast;
      }

      if (make != null) {
        final at = _preferredSpawn(run, swappedInto);
        created[at] = make;
      }
    }

    // Expand any specials that were themselves part of a match (chain them).
    final expanded = <Point<int>>{};
    for (final p in toClear) {
      _expandSpecial(p, expanded);
    }
    toClear.addAll(expanded);

    final triggered = toClear.any((p) => grid[p.x][p.y].isSpecial);

    // Clear everything, then stamp in the newly created power-ups.
    for (final p in toClear) {
      grid[p.x][p.y] = Cell(-1);
    }
    created.forEach((p, sp) {
      // Keep the colour of that cell's run for colour-clear targeting variety.
      grid[p.x][p.y] = Cell(_randomGem(), sp);
    });

    return ClearResult(toClear, created, triggered);
  }

  Point<int> _preferredSpawn(List<Point<int>> run, Point<int>? swappedInto) {
    if (swappedInto != null && run.contains(swappedInto)) return swappedInto;
    return run[run.length ~/ 2];
  }

  /// If [p] holds a special, add all the cells it would detonate to [out].
  void _expandSpecial(Point<int> p, Set<Point<int>> out) {
    final cell = grid[p.x][p.y];
    switch (cell.special) {
      case Special.none:
        return;
      case Special.rowBlast:
        for (int c = 0; c < cols; c++) {
          out.add(Point(p.x, c));
        }
        break;
      case Special.colBlast:
        for (int r = 0; r < rows; r++) {
          out.add(Point(r, p.y));
        }
        break;
      case Special.bomb:
        for (int dr = -1; dr <= 1; dr++) {
          for (int dc = -1; dc <= 1; dc++) {
            final nr = p.x + dr, nc = p.y + dc;
            if (inBounds(nr, nc)) out.add(Point(nr, nc));
          }
        }
        break;
      case Special.colorClear:
        final colour = cell.type;
        for (int r = 0; r < rows; r++) {
          for (int c = 0; c < cols; c++) {
            if (grid[r][c].type == colour) out.add(Point(r, c));
          }
        }
        break;
    }
  }

  /// Manually activate a special gem (e.g. player swaps two specials or swaps a
  /// special with a normal gem to trigger it). Returns cleared cells.
  Set<Point<int>> detonate(Point<int> p) {
    final out = <Point<int>>{p};
    _expandSpecial(p, out);
    // Also chain any specials caught in the blast.
    bool changed = true;
    while (changed) {
      changed = false;
      final snapshot = out.toList();
      for (final q in snapshot) {
        if (grid[q.x][q.y].isSpecial) {
          final before = out.length;
          _expandSpecial(q, out);
          if (out.length != before) changed = true;
        }
      }
    }
    for (final q in out) {
      grid[q.x][q.y] = Cell(-1);
    }
    return out;
  }

  bool anySpecialAt(Point<int> a, Point<int> b) =>
      grid[a.x][a.y].isSpecial || grid[b.x][b.y].isSpecial;

  /// Gravity: gems fall into empty cells. Returns destination -> rows fallen.
  Map<Point<int>, int> applyGravity() {
    final fell = <Point<int>, int>{};
    for (int c = 0; c < cols; c++) {
      int writeRow = rows - 1;
      for (int r = rows - 1; r >= 0; r--) {
        if (!grid[r][c].isEmpty) {
          if (writeRow != r) {
            grid[writeRow][c] = grid[r][c];
            grid[r][c] = Cell(-1);
            fell[Point(writeRow, c)] = writeRow - r;
          }
          writeRow--;
        }
      }
    }
    return fell;
  }

  /// Fill empty cells at the top with new random gems. Returns new cells.
  Set<Point<int>> refill() {
    final created = <Point<int>>{};
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows; r++) {
        if (grid[r][c].isEmpty) {
          grid[r][c] = Cell(_randomGem());
          created.add(Point(r, c));
        }
      }
    }
    return created;
  }

  bool hasPossibleMove() {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (grid[r][c].isSpecial) return true;
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

  void reshuffle() {
    final flat = <Cell>[];
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
