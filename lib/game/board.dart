import 'dart:math';

import '../models/gem.dart';

/// A grid position.
class Pos {
  const Pos(this.row, this.col);
  final int row;
  final int col;

  @override
  bool operator ==(Object other) =>
      other is Pos && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => '($row,$col)';
}

/// Describes one gem's movement during a resolve step, so the UI can animate
/// from [from] to [to]. When [from] is null, the gem spawned above the board.
class GemMove {
  GemMove({required this.gem, required this.from, required this.to});
  final Gem gem;
  final Pos? from;
  final Pos to;
}

/// The result of resolving the board after a swap: a sequence of cascade
/// steps. Each step is the set of gems cleared plus the score it earned.
class ResolveStep {
  ResolveStep({
    required this.cleared,
    required this.clearedTypes,
    required this.moves,
    required this.gained,
    required this.cascadeLevel,
  });

  /// Positions cleared in this step (pre-collapse coordinates).
  final Set<Pos> cleared;

  /// The gem type at each cleared position, captured before removal so the UI
  /// can render accurate colors even after the cells are emptied.
  final Map<Pos, GemType> clearedTypes;

  /// Gems that fell / spawned to fill gaps after clearing.
  final List<GemMove> moves;

  final int gained;
  final int cascadeLevel;
}

/// Pure game logic for a Match-3 board. Holds no UI concerns; the widget layer
/// reads [grid] and plays back [ResolveStep]s as animations.
class Board {
  Board({
    required this.rows,
    required this.cols,
    required this.gemTypeCount,
    int? seed,
  }) : _rng = Random(seed) {
    _reset();
  }

  final int rows;
  final int cols;
  final int gemTypeCount;
  final Random _rng;

  int _nextId = 0;
  late List<List<Gem>> grid;

  List<GemType> get _availableTypes =>
      GemType.values.take(gemTypeCount).toList();

  Gem _randomGem() =>
      Gem(id: _nextId++, type: _availableTypes[_rng.nextInt(gemTypeCount)]);

  /// A throwaway gem used only to allocate the grid before cells are filled.
  Gem get _placeholder => Gem(id: -1, type: GemType.ruby);

  /// Build a starting grid that has NO pre-existing matches. Generation is
  /// single-pass and bounded: each cell re-rolls a few times to avoid forming
  /// an immediate match, then falls back to any type. We deliberately do NOT
  /// loop on hasAvailableMove() here (that was O((r*c)^2) per attempt and could
  /// stall the first frame); if the rare match-free board has no legal move,
  /// reshuffle() is called lazily the first time it's needed.
  void _reset() {
    // IMPORTANT: allocate `grid` FIRST, then fill each cell, so that
    // `_wouldMatchOnFill` can safely read already-placed neighbours. (Doing
    // this inside a single List.generate would read `grid` before it is
    // assigned and throw a LateInitializationError -> blank screen.)
    grid = List.generate(
      rows,
      (_) => List<Gem>.filled(cols, _placeholder, growable: false),
    );

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        Gem gem = _randomGem();
        // Bounded re-rolls to avoid forming an immediate match on placement.
        for (var attempt = 0; attempt < 12; attempt++) {
          if (!_wouldMatchOnFill(r, c, gem.type)) break;
          gem = _randomGem();
        }
        grid[r][c] = gem;
      }
    }

    // Guarantee at least one legal move without an expensive generate loop.
    if (!hasAvailableMove()) {
      reshuffle();
    }
  }

  bool _wouldMatchOnFill(int r, int c, GemType type) {
    // Check two to the left.
    if (c >= 2 &&
        grid[r][c - 1].type == type &&
        grid[r][c - 2].type == type) {
      return true;
    }
    // Check two above.
    if (r >= 2 &&
        grid[r - 1][c].type == type &&
        grid[r - 2][c].type == type) {
      return true;
    }
    return false;
  }

  bool inBounds(Pos p) =>
      p.row >= 0 && p.row < rows && p.col >= 0 && p.col < cols;

  bool areAdjacent(Pos a, Pos b) =>
      (a.row == b.row && (a.col - b.col).abs() == 1) ||
      (a.col == b.col && (a.row - b.row).abs() == 1);

  void _swap(Pos a, Pos b) {
    final tmp = grid[a.row][a.col];
    grid[a.row][a.col] = grid[b.row][b.col];
    grid[b.row][b.col] = tmp;
  }

  /// Returns true if swapping [a] and [b] would create at least one match.
  bool isValidSwap(Pos a, Pos b) {
    if (!areAdjacent(a, b)) return false;
    _swap(a, b);
    final hasMatch = _findMatches().isNotEmpty;
    _swap(a, b); // revert
    return hasMatch;
  }

  /// Perform a swap that is already known to be valid.
  void applySwap(Pos a, Pos b) => _swap(a, b);

  /// Find every position that is part of a horizontal or vertical run of 3+.
  Set<Pos> _findMatches() {
    final matched = <Pos>{};

    // Horizontal runs.
    for (var r = 0; r < rows; r++) {
      var runStart = 0;
      for (var c = 1; c <= cols; c++) {
        final same = c < cols && grid[r][c].type == grid[r][runStart].type;
        if (!same) {
          if (c - runStart >= 3) {
            for (var k = runStart; k < c; k++) {
              matched.add(Pos(r, k));
            }
          }
          runStart = c;
        }
      }
    }

    // Vertical runs.
    for (var c = 0; c < cols; c++) {
      var runStart = 0;
      for (var r = 1; r <= rows; r++) {
        final same = r < rows && grid[r][c].type == grid[runStart][c].type;
        if (!same) {
          if (r - runStart >= 3) {
            for (var k = runStart; k < r; k++) {
              matched.add(Pos(k, c));
            }
          }
          runStart = r;
        }
      }
    }

    return matched;
  }

  /// Fully resolve the board in one call (no intermediate animation frames).
  /// Kept for tests and headless scoring; the UI uses the stepwise API below.
  List<ResolveStep> resolve() {
    final steps = <ResolveStep>[];
    while (true) {
      final step = clearMatches(cascadeLevel: steps.length + 1);
      if (step == null) break;
      collapseAndRefill();
      steps.add(step);
    }
    return steps;
  }

  /// Clear the currently-matched cells (marking them removed) WITHOUT
  /// collapsing. Returns the step describing what was cleared and the score
  /// gained, or null if there are no matches. Colors/types are captured before
  /// removal so the UI can render accurate clear effects.
  ///
  /// Call [collapseAndRefill] afterwards to drop and refill the board.
  ResolveStep? clearMatches({required int cascadeLevel}) {
    final matches = _findMatches();
    if (matches.isEmpty) return null;

    final base = matches.length * 60;
    final sizeBonus = matches.length > 3 ? (matches.length - 3) * 50 : 0;
    final gained = (base + sizeBonus) * cascadeLevel;

    // Capture types before removing so the UI can render accurate effects.
    final clearedTypes = <Pos, GemType>{
      for (final p in matches) p: grid[p.row][p.col].type,
    };

    for (final p in matches) {
      grid[p.row][p.col] = _Removed.instance;
    }

    return ResolveStep(
      cleared: matches,
      clearedTypes: clearedTypes,
      moves: const [],
      gained: gained,
      cascadeLevel: cascadeLevel,
    );
  }

  /// The currently-matched positions mapped to their gem types, WITHOUT
  /// mutating the board. Used by the UI to render the clear effect before the
  /// gems are actually removed.
  Map<Pos, GemType> matchTypes() => {
        for (final p in _findMatches()) p: grid[p.row][p.col].type,
      };

  /// True if a cell is currently an empty (cleared) slot awaiting collapse.
  bool isEmpty(int r, int c) => identical(grid[r][c], _Removed.instance);

  /// Are there any matches on the board right now?
  bool hasMatches() => _findMatches().isNotEmpty;

  /// Public collapse+refill used by the stepwise UI flow.
  List<GemMove> collapseAndRefill() => _collapseAndRefill();

  /// After cells are marked removed, drop surviving gems down and spawn new
  /// ones at the top. Returns the movements for animation.
  List<GemMove> _collapseAndRefill() {
    final moves = <GemMove>[];

    for (var c = 0; c < cols; c++) {
      // Walk from bottom up, packing surviving gems downward.
      var writeRow = rows - 1;
      for (var r = rows - 1; r >= 0; r--) {
        if (!identical(grid[r][c], _Removed.instance)) {
          if (writeRow != r) {
            final gem = grid[r][c];
            grid[writeRow][c] = gem;
            grid[r][c] = _Removed.instance;
            moves.add(GemMove(gem: gem, from: Pos(r, c), to: Pos(writeRow, c)));
          }
          writeRow--;
        }
      }
      // Fill the remaining top cells with fresh gems dropping in from above.
      for (var r = writeRow; r >= 0; r--) {
        final gem = _randomGem();
        grid[r][c] = gem;
        moves.add(GemMove(gem: gem, from: null, to: Pos(r, c)));
      }
    }

    return moves;
  }

  /// Does any single adjacent swap produce a match? Used to detect deadlocks.
  bool hasAvailableMove() {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        // Try swapping right and down only (covers all adjacent pairs once).
        for (final d in const [Pos(0, 1), Pos(1, 0)]) {
          final b = Pos(r + d.row, c + d.col);
          if (!inBounds(b)) continue;
          if (isValidSwap(Pos(r, c), b)) return true;
        }
      }
    }
    return false;
  }

  /// Reshuffle the board in place when no moves remain. Tries to reach a
  /// match-free layout that has a legal move, but is capped so it can never
  /// hang: after a bounded number of attempts it accepts the best layout it
  /// found (any move available, matches tolerated), guaranteeing termination.
  void reshuffle() {
    final flat = <Gem>[for (final row in grid) ...row];

    void writeFlat() {
      var i = 0;
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          grid[r][c] = flat[i++];
        }
      }
    }

    for (var attempt = 0; attempt < 200; attempt++) {
      flat.shuffle(_rng);
      writeFlat();
      if (_findMatches().isEmpty && hasAvailableMove()) return;
    }
    // Fallback: prefer at least a playable layout even if not match-free.
    for (var attempt = 0; attempt < 200; attempt++) {
      flat.shuffle(_rng);
      writeFlat();
      if (hasAvailableMove()) return;
    }
    // Last resort: leave the last shuffle in place (extremely unlikely path).
  }
}

/// Sentinel placeholder for a cleared cell during the collapse phase.
class _Removed extends Gem {
  _Removed._() : super(id: -1, type: GemType.ruby);
  static final _Removed instance = _Removed._();
}
