import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'audio_manager.dart';
import 'game_board.dart';
import 'gem_painter.dart';
import 'levels.dart';
import 'storage.dart';
import 'theme.dart';

/// The main playable screen for a single level. Owns the [GameBoard] logic and
/// orchestrates the animation pipeline: swap -> clear (+ power-ups) -> gravity
/// -> refill -> repeat (cascades), while tracking score against the level's
/// objective (target score within a move budget).
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.level});

  final LevelDef level;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const int rows = 8;
  static const int cols = 8;

  late GameBoard board;
  late LevelDef level;

  int score = 0;
  int moves = 0;
  int combo = 0;
  bool busy = false;
  bool finished = false;
  bool won = false;
  bool newHighScore = false;

  Point<int>? selected;

  late List<List<double>> popScale;
  late List<List<double>> glow;
  late List<List<Offset>> offset;

  @override
  void initState() {
    super.initState();
    level = widget.level;
    _startLevel(level);
    AudioManager.instance.startMusic();
  }

  void _startLevel(LevelDef lvl) {
    level = lvl;
    board = GameBoard(rows: rows, cols: cols, gemTypes: lvl.gemTypes);
    score = 0;
    moves = lvl.moves;
    combo = 0;
    busy = false;
    finished = false;
    won = false;
    newHighScore = false;
    selected = null;
    _initAnimBuffers();
    setState(() {});
  }

  void _initAnimBuffers() {
    popScale = List.generate(rows, (_) => List.filled(cols, 1.0));
    glow = List.generate(rows, (_) => List.filled(cols, 0.0));
    offset = List.generate(rows, (_) => List.filled(cols, Offset.zero));
  }

  double get progress => (score / level.targetScore).clamp(0.0, 1.0);

  // ---- Input -------------------------------------------------------------

  Future<void> _onCellTap(int r, int c) async {
    if (busy || finished) return;
    AudioManager.instance.play('select', volume: 0.4);
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
      setState(() {
        glow[selected!.x][selected!.y] = 0.0;
        selected = null;
      });
      return;
    }
    if (board.areAdjacent(selected!, tapped)) {
      final a = selected!;
      setState(() {
        glow[a.x][a.y] = 0.0;
        selected = null;
      });
      await _trySwap(a, tapped);
    } else {
      setState(() {
        glow[selected!.x][selected!.y] = 0.0;
        selected = tapped;
        glow[r][c] = 1.0;
      });
    }
  }

  Future<void> _handleSwipe(int r, int c, Offset delta) async {
    if (busy || finished) return;
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
    final hasSpecial = board.anySpecialAt(a, b);
    final valid = hasSpecial || board.wouldSwapMatch(a, b);
    await _animateSwap(a, b, revert: !valid);

    if (!valid) {
      AudioManager.instance.play('invalid', volume: 0.5);
      HapticFeedback.mediumImpact();
      busy = false;
      setState(() {});
      return;
    }

    board.applySwap(a, b);
    setState(() {});
    AudioManager.instance.play('swap', volume: 0.5);
    HapticFeedback.lightImpact();

    moves--;
    combo = 0;

    // If the player swapped a special into place, detonate it immediately.
    if (board.grid[b.x][b.y].isSpecial || board.grid[a.x][a.y].isSpecial) {
      final trigger = board.grid[b.x][b.y].isSpecial ? b : a;
      final cleared = board.detonate(trigger);
      if (cleared.isNotEmpty) {
        AudioManager.instance.play('powerup', volume: 0.7);
        combo++;
        score += cleared.length * 15;
        await _animatePop(cleared);
        // detonate() already emptied the cells; just reset transient state.
        for (final p in cleared) {
          popScale[p.x][p.y] = 1.0;
          glow[p.x][p.y] = 0.0;
        }
        final fell = board.applyGravity();
        final created = board.refill();
        await _animateFall(fell, created);
      }
    }

    await _resolveCascades(swappedInto: b);

    _checkEnd();
    if (!finished && !board.hasPossibleMove()) {
      board.reshuffle();
    }
    busy = false;
    setState(() {});
  }

  // ---- Animation pipeline ------------------------------------------------

  Future<void> _animateSwap(Point<int> a, Point<int> b,
      {required bool revert}) async {
    final dir = Offset((b.y - a.y).toDouble(), (b.x - a.x).toDouble());
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

  Future<void> _resolveCascades({Point<int>? swappedInto}) async {
    var first = true;
    while (true) {
      final result = board.resolveClearStep(
          swappedInto: first ? swappedInto : null);
      first = false;
      if (result.cleared.isEmpty) break;

      combo++;
      final gained = result.cleared.length * 10 * combo;
      score += gained;

      if (result.createdSpecials.isNotEmpty || result.triggeredSpecials) {
        AudioManager.instance.play('powerup', volume: 0.7);
      } else {
        AudioManager.instance
            .play(combo > 1 ? 'cascade' : 'match', volume: 0.6);
      }
      HapticFeedback.heavyImpact();

      await _animatePop(result.cleared);

      // The clear already emptied cells and stamped in specials inside
      // resolveClearStep; just refresh transient anim state for those cells.
      for (final p in result.cleared) {
        popScale[p.x][p.y] = 1.0;
        glow[p.x][p.y] = 0.0;
      }
      for (final p in result.createdSpecials.keys) {
        glow[p.x][p.y] = 0.6; // newly created power-up shines
      }
      setState(() {});

      final fell = board.applyGravity();
      final created = board.refill();
      await _animateFall(fell, created);
    }
  }

  Future<void> _animatePop(Set<Point<int>> cells) async {
    for (final p in cells) {
      glow[p.x][p.y] = 1.0;
    }
    const steps = 6;
    for (int i = 1; i <= steps; i++) {
      final s = 1.0 - (i / steps);
      setState(() {
        for (final p in cells) {
          popScale[p.x][p.y] = s;
        }
      });
      await Future.delayed(const Duration(milliseconds: 18));
    }
  }

  Future<void> _animateFall(
      Map<Point<int>, int> fell, Set<Point<int>> created) async {
    fell.forEach((p, dist) {
      offset[p.x][p.y] = Offset(0, -dist.toDouble());
    });
    for (final p in created) {
      offset[p.x][p.y] = Offset(0, -(p.x + 1).toDouble());
      popScale[p.x][p.y] = 1.0;
    }
    const steps = 10;
    for (int i = 1; i <= steps; i++) {
      final t = _easeOutLite(i / steps);
      setState(() {
        fell.forEach((p, dist) {
          offset[p.x][p.y] = Offset(0, -dist * (1 - t));
        });
        for (final p in created) {
          offset[p.x][p.y] = Offset(0, -(p.x + 1) * (1 - t));
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

  double _easeOutLite(double t) {
    final o = t - 1.0;
    return 1 + o * o * o + 0.08 * (1 - t) * sin(t * pi * 2);
  }

  // ---- End of level ------------------------------------------------------

  Future<void> _checkEnd() async {
    if (score >= level.targetScore) {
      finished = true;
      won = true;
      AudioManager.instance.play('levelup', volume: 0.8);
      HapticFeedback.heavyImpact();
      await Storage.instance.unlockLevel(level.index + 1);
    } else if (moves <= 0) {
      finished = true;
      won = false;
      AudioManager.instance.play('gameover', volume: 0.7);
    }
    if (finished) {
      newHighScore = await Storage.instance.submitScore(score);
      setState(() {});
    }
  }

  // ---- UI ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: GameTheme.background),
        child: SafeArea(
          child: Column(
            children: [
              _buildHud(),
              _buildObjectiveBar(),
              const SizedBox(height: 6),
              Expanded(
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final side =
                          min(constraints.maxWidth, constraints.maxHeight) - 16;
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
          const SizedBox(width: 22),
          _hudStat('MOVES', '$moves'),
          if (combo > 1) ...[
            const SizedBox(width: 22),
            _hudStat('COMBO', 'x$combo', highlight: true),
          ],
          const Spacer(),
          IconButton(
            onPressed: busy ? null : () => _startLevel(level),
            icon:
                const Icon(Icons.refresh, color: GameTheme.textLight, size: 22),
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

  Widget _buildObjectiveBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Level ${level.displayNumber} · ${level.name}',
                  style: GameTheme.hudLabel),
              Text('Target ${level.targetScore}', style: GameTheme.hudLabel),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(GameTheme.accent),
            ),
          ),
        ],
      ),
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
              color: Color(0x66000000), blurRadius: 20, offset: Offset(0, 10)),
        ],
      ),
      child: Stack(
        children: [
          for (int r = 0; r < rows; r++)
            for (int c = 0; c < cols; c++) _buildGem(r, c, cell - 12 / cols),
          if (finished) _buildEndOverlay(),
        ],
      ),
    );
  }

  Widget _buildGem(int r, int c, double cell) {
    final cellData = board.grid[r][c];
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
              type: cellData.type,
              special: cellData.special,
              scale: popScale[r][c],
              glow: glow[r][c],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEndOverlay() {
    final hasNext = level.index + 1 < Levels.count;
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(won ? 'LEVEL CLEAR!' : 'OUT OF MOVES',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: won ? GameTheme.accent : GameTheme.textLight,
                  )),
              const SizedBox(height: 6),
              Text('Score: $score',
                  style: const TextStyle(
                      fontSize: 20,
                      color: GameTheme.textLight,
                      fontWeight: FontWeight.w700)),
              if (newHighScore) ...[
                const SizedBox(height: 4),
                const Text('🏆 New High Score!',
                    style: TextStyle(color: GameTheme.accent, fontSize: 14)),
              ],
              const SizedBox(height: 20),
              if (won && hasNext)
                _overlayButton(
                  'Next Level',
                  Icons.arrow_forward_rounded,
                  () {
                    AudioManager.instance.play('button');
                    _startLevel(Levels.byIndex(level.index + 1));
                  },
                ),
              if (won && !hasNext)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('🎉 All levels complete!',
                      style: TextStyle(
                          color: GameTheme.textLight, fontSize: 15)),
                ),
              const SizedBox(height: 10),
              _overlayButton('Replay', Icons.replay, () {
                AudioManager.instance.play('button');
                _startLevel(level);
              }, secondary: true),
              const SizedBox(height: 10),
              _overlayButton('Levels', Icons.grid_view_rounded, () {
                AudioManager.instance.play('button');
                Navigator.of(context).maybePop();
              }, secondary: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _overlayButton(String label, IconData icon, VoidCallback onTap,
      {bool secondary = false}) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor:
            secondary ? Colors.white24 : GameTheme.accent,
        foregroundColor:
            secondary ? GameTheme.textLight : const Color(0xFF2D1B69),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      icon: Icon(icon),
      label: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }

  Widget _buildFooter() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 10, top: 2),
      child: Text(
        'Match 4 = line blast · L/T = bomb · 5 = color clear',
        style: TextStyle(color: GameTheme.textDim, fontSize: 11),
      ),
    );
  }
}
