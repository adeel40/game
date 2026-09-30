import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_board.dart';
import 'gem_painter.dart';
import 'theme.dart';

/// The main playable screen. Owns the [GameBoard] logic and orchestrates the
/// animation pipeline: swap -> clear matches -> gravity -> refill -> repeat
/// (cascades) while updating score, combo and moves.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  static const int rows = 8;
  static const int cols = 8;
  static const int startMoves = 25;

  late GameBoard board;
  int score = 0;
  int moves = startMoves;
  int combo = 0;
  bool busy = false; // true while animating a cascade
  bool gameOver = false;

  Point<int>? selected;

  // Per-cell transient animation values.
  late List<List<double>> popScale; // 1.0 normal, animates 1->0 when clearing
  late List<List<double>> glow; // selection / match glow
  late List<List<Offset>> offset; // visual offset for fall/swap animation

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    board = GameBoard(rows: rows, cols: cols, gemTypes: 6);
    score = 0;
    moves = startMoves;
    combo = 0;
    busy = false;
    gameOver = false;
    selected = null;
    _initAnimBuffers();
    setState(() {});
  }

  void _initAnimBuffers() {
    popScale = List.generate(rows, (_) => List.filled(cols, 1.0));
    glow = List.generate(rows, (_) => List.filled(cols, 0.0));
    offset = List.generate(rows, (_) => List.filled(cols, Offset.zero));
  }

  Future<void> _onCellTap(int r, int c) async {
    if (busy || gameOver) return;
    HapticFeedback.selectionClick();
    final tapped = Point(r, c);

    if (selected == null) {
      setState(() {
        selected = tapped;
        glow[r][c] = 1.0;
      });
      return;
    }

    if (selected == tapped) {
      // Deselect.
      setState(() {
        glow[selected!.x][selected!.y] = 0.0;
        selected = null;
      });
      return;
    }

    if (board.areAdjacent(selected!, tapped)) {
      final a = selected!;
      final b = tapped;
      setState(() {
        glow[a.x][a.y] = 0.0;
        selected = null;
      });
      await _trySwap(a, b);
    } else {
      // Move selection to the new gem.
      setState(() {
        glow[selected!.x][selected!.y] = 0.0;
        selected = tapped;
        glow[r][c] = 1.0;
      });
    }
  }

  Future<void> _handleSwipe(int r, int c, Offset delta) async {
    if (busy || gameOver) return;
    int tr = r, tc = c;
    if (delta.dx.abs() > delta.dy.abs()) {
      tc += delta.dx > 0 ? 1 : -1;
    } else {
      tr += delta.dy > 0 ? 1 : -1;
    }
    if (!board.inBounds(tr, tc)) return;
    if (selected != null) {
      setState(() {
        glow[selected!.x][selected!.y] = 0.0;
        selected = null;
      });
    }
    await _trySwap(Point(r, c), Point(tr, tc));
  }

  Future<void> _trySwap(Point<int> a, Point<int> b) async {
    busy = true;
    final valid = board.wouldSwapMatch(a, b);
    await _animateSwap(a, b, revert: !valid);

    if (!valid) {
      HapticFeedback.mediumImpact();
      busy = false;
      setState(() {});
      return;
    }

    board.applySwap(a, b);
    setState(() {});
    HapticFeedback.lightImpact();

    moves--;
    combo = 0;
    await _resolveCascades();

    if (moves <= 0) {
      gameOver = true;
    } else if (!board.hasPossibleMove()) {
      board.reshuffle();
    }

    busy = false;
    setState(() {});
  }

  /// Visually slide two adjacent gems past each other. If [revert], slide back.
  Future<void> _animateSwap(Point<int> a, Point<int> b,
      {required bool revert}) async {
    final dir = Offset(
      (b.y - a.y).toDouble(),
      (b.x - a.x).toDouble(),
    );
    const steps = 8;
    for (int i = 1; i <= steps; i++) {
      final t = i / steps;
      setState(() {
        offset[a.x][a.y] = dir * t;
        offset[b.x][b.y] = dir * -t;
      });
      await Future.delayed(const Duration(milliseconds: 14));
    }
    if (revert) {
      for (int i = steps - 1; i >= 0; i--) {
        final t = i / steps;
        setState(() {
          offset[a.x][a.y] = dir * t;
          offset[b.x][b.y] = dir * -t;
        });
        await Future.delayed(const Duration(milliseconds: 14));
      }
    }
    setState(() {
      offset[a.x][a.y] = Offset.zero;
      offset[b.x][b.y] = Offset.zero;
    });
  }

  /// Core loop: keep clearing matches, applying gravity and refilling until
  /// the board is stable. Each iteration increases the combo multiplier.
  Future<void> _resolveCascades() async {
    while (true) {
      final matches = board.findMatches();
      if (matches.isEmpty) break;

      combo++;
      final gained = matches.length * 10 * combo;
      score += gained;
      HapticFeedback.heavyImpact();

      // Pop animation on matched cells.
      for (final p in matches) {
        glow[p.x][p.y] = 1.0;
      }
      const steps = 6;
      for (int i = 1; i <= steps; i++) {
        final s = 1.0 - (i / steps);
        setState(() {
          for (final p in matches) {
            popScale[p.x][p.y] = s;
          }
        });
        await Future.delayed(const Duration(milliseconds: 18));
      }

      board.clearCells(matches);
      // Reset the cleared cells' transient state.
      for (final p in matches) {
        popScale[p.x][p.y] = 1.0;
        glow[p.x][p.y] = 0.0;
      }
      setState(() {});

      // Gravity + fall animation.
      final fell = board.applyGravity();
      final created = board.refill();
      await _animateFall(fell, created);
    }
  }

  /// Animate gems dropping into place after gravity + refill.
  Future<void> _animateFall(
      Map<Point<int>, int> fell, Set<Point<int>> created) async {
    // Give every moved/created cell an initial upward offset then ease to 0.
    const cellVisualStep = 1.0; // in cell units
    fell.forEach((p, dist) {
      offset[p.x][p.y] = Offset(0, -dist * cellVisualStep);
    });
    for (final p in created) {
      // New gems drop from above the top edge.
      offset[p.x][p.y] = Offset(0, -(p.x + 1) * cellVisualStep);
      popScale[p.x][p.y] = 1.0;
    }

    const steps = 10;
    for (int i = 1; i <= steps; i++) {
      final t = _easeOutBounceLite(i / steps);
      setState(() {
        fell.forEach((p, dist) {
          offset[p.x][p.y] = Offset(0, -dist * cellVisualStep * (1 - t));
        });
        for (final p in created) {
          final start = (p.x + 1) * cellVisualStep;
          offset[p.x][p.y] = Offset(0, -start * (1 - t));
        }
      });
      await Future.delayed(const Duration(milliseconds: 16));
    }
    setState(() {
      fell.forEach((p, _) => offset[p.x][p.y] = Offset.zero);
      for (final p in created) {
        offset[p.x][p.y] = Offset.zero;
      }
    });
  }

  // A gentle ease-out with a tiny overshoot for a lively drop.
  double _easeOutBounceLite(double t) {
    final o = t - 1.0;
    return 1 + o * o * o + 0.08 * (1 - t) * sin(t * pi * 2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: GameTheme.background),
        child: SafeArea(
          child: Column(
            children: [
              _buildHud(),
              const SizedBox(height: 8),
              Expanded(
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final side = min(constraints.maxWidth,
                              constraints.maxHeight) -
                          16;
                      return _buildBoard(side);
                    },
                  ),
                ),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHud() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios_new,
                color: GameTheme.textLight, size: 20),
          ),
          const Spacer(),
          _hudStat('SCORE', '$score'),
          const SizedBox(width: 24),
          _hudStat('MOVES', '$moves'),
          if (combo > 1) ...[
            const SizedBox(width: 24),
            _hudStat('COMBO', 'x$combo', highlight: true),
          ],
          const Spacer(),
          IconButton(
            onPressed: busy ? null : _reset,
            icon: const Icon(Icons.refresh,
                color: GameTheme.textLight, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _hudStat(String label, String value, {bool highlight = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: GameTheme.hudLabel),
        Text(
          value,
          style: GameTheme.hudValue.copyWith(
            color: highlight ? GameTheme.accent : GameTheme.textLight,
          ),
        ),
      ],
    );
  }

  Widget _buildBoard(double side) {
    final cell = side / cols;
    return Container(
      width: side,
      height: side,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: GameTheme.boardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GameTheme.boardBorder, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          for (int r = 0; r < rows; r++)
            for (int c = 0; c < cols; c++) _buildGem(r, c, cell - 12 / cols),
          if (gameOver) _buildGameOverOverlay(),
        ],
      ),
    );
  }

  Widget _buildGem(int r, int c, double cell) {
    final type = board.grid[r][c];
    final off = offset[r][c];
    return Positioned(
      left: c * cell + off.dx * cell,
      top: r * cell + off.dy * cell,
      width: cell,
      height: cell,
      child: GestureDetector(
        onTap: () => _onCellTap(r, c),
        onPanEnd: (details) {
          final v = details.velocity.pixelsPerSecond;
          if (v.distance > 60) _handleSwipe(r, c, v);
        },
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: CustomPaint(
            painter: GemPainter(
              type: type,
              scale: popScale[r][c],
              glow: glow[r][c],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameOverOverlay() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('GAME OVER',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: GameTheme.textLight,
                  )),
              const SizedBox(height: 8),
              Text('Score: $score',
                  style: const TextStyle(
                    fontSize: 20,
                    color: GameTheme.accent,
                    fontWeight: FontWeight.w700,
                  )),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _reset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GameTheme.accent,
                  foregroundColor: const Color(0xFF2D1B69),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                icon: const Icon(Icons.replay),
                label: const Text('Play Again',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12, top: 4),
      child: Text(
        'Tap two adjacent gems or swipe to swap • Match 3+',
        style: TextStyle(color: GameTheme.textDim, fontSize: 12),
      ),
    );
  }
}
