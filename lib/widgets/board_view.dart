import 'package:flutter/material.dart';

import '../game/board.dart';
import '../game/game_controller.dart';
import '../game/sound_manager.dart';
import '../models/gem.dart';
import 'gem_tile.dart';
import 'particles.dart';

/// Renders the board and drives all board animations: player swaps, invalid
/// swap "shakes", cascading clears with particle bursts, and gems falling in
/// to refill. Communicates results back to [GameController].
class BoardView extends StatefulWidget {
  const BoardView({super.key, required this.controller});

  final GameController controller;

  @override
  State<BoardView> createState() => BoardViewState();
}

/// Public so the game screen can drive [showHint] via a GlobalKey.
class BoardViewState extends State<BoardView> {
  Pos? _selected;
  final Set<Pos> _clearing = {};
  final Set<Pos> _hint = {};
  final List<_Burst> _bursts = [];

  Board get board => widget.controller.board;

  /// Highlight one legal move for a few seconds so the player can see what to
  /// do. Called from the game screen's Hint button.
  void showHint() {
    final hint = board.findHint();
    if (hint == null) return;
    setState(() {
      _hint
        ..clear()
        ..addAll(hint);
    });
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _hint.clear());
    });
  }

  Future<void> _onTapCell(Pos p) async {
    final c = widget.controller;
    if (c.busy || c.status != GameStatus.playing) return;

    if (_selected == null) {
      SoundManager.instance.select();
      setState(() => _selected = p);
      return;
    }

    if (_selected == p) {
      setState(() => _selected = null);
      return;
    }

    if (board.areAdjacent(_selected!, p)) {
      await _attemptSwap(_selected!, p);
      setState(() => _selected = null);
    } else {
      // Re-select the newly tapped gem.
      SoundManager.instance.select();
      setState(() => _selected = p);
    }
  }

  Future<void> _handleSwipe(Pos from, Offset delta) async {
    final c = widget.controller;
    if (c.busy || c.status != GameStatus.playing) return;
    Pos? target;
    if (delta.dx.abs() > delta.dy.abs()) {
      target = Pos(from.row, from.col + (delta.dx > 0 ? 1 : -1));
    } else {
      target = Pos(from.row + (delta.dy > 0 ? 1 : -1), from.col);
    }
    if (board.inBounds(target)) {
      setState(() => _selected = null);
      await _attemptSwap(from, target);
    }
  }

  Future<void> _attemptSwap(Pos a, Pos b) async {
    final c = widget.controller;
    if (!board.isValidSwap(a, b)) {
      // Show a brief invalid nudge by flashing selection.
      SoundManager.instance.invalid();
      setState(() => _selected = a);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (mounted) setState(() => _selected = null);
      return;
    }

    c.setBusy(true);

    // 1) Animate the swap itself (AnimatedPositioned reacts to the grid change).
    c.applyPlayerSwap(a, b);
    await Future<void>.delayed(const Duration(milliseconds: 240));

    // 2) Play cascade layers one at a time against the real intermediate grid.
    var cascade = 0;
    while (board.hasMatches()) {
      cascade++;

      // 2a) Mark the about-to-clear gems so they fade+shrink, and burst.
      final types = board.matchTypes();
      SoundManager.instance.match(cascade);
      setState(() {
        _clearing
          ..clear()
          ..addAll(types.keys);
        types.forEach((p, t) {
          _bursts.add(_Burst(pos: p, color: t.glowColor));
        });
      });
      await Future<void>.delayed(const Duration(milliseconds: 240));

      // 2b) Now actually remove the gems (scores this cascade layer).
      c.clearStep(cascade);
      if (mounted) setState(() => _clearing.clear());

      // 2c) Collapse survivors down and refill; AnimatedPositioned animates it.
      c.collapseStep();
      await Future<void>.delayed(const Duration(milliseconds: 280));
    }

    c.finishTurn();
    if (mounted) c.setBusy(false);
  }

  @override
  Widget build(BuildContext context) {
    // Compute a finite, square board size from the available width. Using
    // MediaQuery (rather than LayoutBuilder inside a Center) guarantees the
    // constraints are always bounded, so `cell` can never become
    // Infinity/NaN — which previously caused a blank/crashed screen.
    final media = MediaQuery.of(context);
    final maxWidth = media.size.width - 24; // account for the parent padding
    // Keep the board within the vertical space too, so it never overflows.
    final maxHeight = media.size.height * 0.62;
    final boardSide = maxWidth < maxHeight ? maxWidth : maxHeight;
    final cell = boardSide / board.cols;
    final boardHeight = cell * board.rows;

    return SizedBox(
      width: cell * board.cols,
      height: boardHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Board backing panel with subtle inner cells.
          Positioned.fill(child: _buildGrid(cell)),
          // Gems (each positioned explicitly).
          for (var r = 0; r < board.rows; r++)
            for (var c = 0; c < board.cols; c++)
              _buildGem(Pos(r, c), cell),
          // Particle bursts.
          for (final burst in _bursts)
            Positioned(
              left: burst.pos.col * cell,
              top: burst.pos.row * cell,
              child: IgnorePointer(
                child: ParticleBurst(
                  color: burst.color,
                  size: cell,
                  onDone: () {
                    if (mounted) setState(() => _bursts.remove(burst));
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGrid(double cell) {
    return CustomPaint(
      size: Size(cell * board.cols, cell * board.rows),
      painter: _GridPainter(rows: board.rows, cols: board.cols),
    );
  }

  Widget _buildGem(Pos p, double cell) {
    // Skip cells that are momentarily empty (cleared, awaiting collapse).
    if (board.isEmpty(p.row, p.col)) {
      return const Positioned(width: 0, height: 0, left: 0, top: 0,
          child: SizedBox.shrink());
    }
    final gem = board.grid[p.row][p.col];
    final selected = _selected == p;
    final clearing = _clearing.contains(p);
    final hinted = _hint.contains(p);

    return AnimatedPositioned(
      key: ValueKey(gem.id),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      left: p.col * cell,
      top: p.row * cell,
      width: cell,
      height: cell,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: clearing ? 0.0 : 1.0,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 220),
          scale: clearing ? 0.3 : 1.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _onTapCell(p),
            onPanEnd: (details) {
              final v = details.velocity.pixelsPerSecond;
              if (v.distance > 100) _handleSwipe(p, v);
            },
            child: GemTile(
                gem: gem, size: cell, selected: selected, hint: hinted),
          ),
        ),
      ),
    );
  }
}

class _Burst {
  _Burst({required this.pos, required this.color});
  final Pos pos;
  final Color color;
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.rows, required this.cols});
  final int rows;
  final int cols;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / cols;
    final bg = Paint()..color = Colors.black.withValues(alpha: 0.22);
    final cellPaint = Paint()..color = Colors.white.withValues(alpha: 0.05);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(20),
      ),
      bg,
    );

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final rect = Rect.fromLTWH(
          c * cell + cell * 0.06,
          r * cell + cell * 0.06,
          cell * 0.88,
          cell * 0.88,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.24)),
          cellPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.rows != rows || old.cols != cols;
}
