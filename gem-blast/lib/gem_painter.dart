import 'dart:math';
import 'package:flutter/material.dart';
import 'game_board.dart';
import 'theme.dart';

/// Draws a single gem into a cell. Ordinary gems are jewel-like rounded shapes
/// with a radial gradient, gloss and specular dot. Power-up gems reuse the body
/// but add an overlay marking their ability:
///   rowBlast -> horizontal arrows, colBlast -> vertical arrows,
///   bomb -> a fuse/burst ring, colorClear -> a rainbow multi-colour body.
class GemPainter extends CustomPainter {
  GemPainter({
    required this.type,
    this.special = Special.none,
    this.scale = 1.0,
    this.glow = 0.0,
  });

  final int type;
  final Special special;
  final double scale;
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    if (type < 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.shortestSide / 2;
    final r = maxR * 0.82 * scale;
    if (r <= 0) return;

    final glowColor = GameTheme.gemGlow[type % GameTheme.gemGlow.length];

    // Extra baseline glow for special gems so they read as "powerful".
    final effectiveGlow = special == Special.none ? glow : max(glow, 0.4);
    if (effectiveGlow > 0) {
      final glowPaint = Paint()
        ..color = glowColor.withValues(alpha: 0.55 * effectiveGlow)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 * effectiveGlow + 2);
      canvas.drawCircle(center, r * (1.0 + 0.25 * effectiveGlow), glowPaint);
    }

    final rect = Rect.fromCircle(center: center, radius: r);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(r * 0.42));

    // Shadow.
    canvas.drawRRect(
      rrect.shift(const Offset(0, 3)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Body.
    if (special == Special.colorClear) {
      _paintRainbowBody(canvas, rrect, rect);
    } else {
      final colors =
          GameTheme.gemGradients[type % GameTheme.gemGradients.length];
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.4),
            radius: 1.0,
            colors: [colors[0], colors[1]],
          ).createShader(rect),
      );
    }

    // Facet edge.
    canvas.drawRRect(
      rrect.deflate(r * 0.05),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08
        ..color = Colors.white.withValues(alpha: 0.18),
    );

    // Gloss highlight.
    final hlRect = Rect.fromLTWH(
      center.dx - r * 0.55,
      center.dy - r * 0.7,
      r * 1.1,
      r * 0.7,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(hlRect, Radius.circular(r * 0.4)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(rect),
    );

    // Specular dot.
    canvas.drawCircle(
      Offset(center.dx - r * 0.3, center.dy - r * 0.35),
      r * 0.12,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );

    _paintSpecialOverlay(canvas, center, r);
  }

  void _paintRainbowBody(Canvas canvas, RRect rrect, Rect rect) {
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            Color(0xFFFF6B6B),
            Color(0xFFFFD54F),
            Color(0xFF81C784),
            Color(0xFF4FC3F7),
            Color(0xFFBA68C8),
            Color(0xFFFF6B6B),
          ],
        ).createShader(rect),
    );
  }

  void _paintSpecialOverlay(Canvas canvas, Offset c, double r) {
    final white = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.12
      ..strokeCap = StrokeCap.round;

    switch (special) {
      case Special.none:
        break;
      case Special.rowBlast:
        _arrow(canvas, c, r, stroke, horizontal: true);
        break;
      case Special.colBlast:
        _arrow(canvas, c, r, stroke, horizontal: false);
        break;
      case Special.bomb:
        // Burst ring + centre dot.
        canvas.drawCircle(
          c,
          r * 0.42,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.1
            ..color = Colors.white.withValues(alpha: 0.9),
        );
        canvas.drawCircle(c, r * 0.14, white);
        for (int i = 0; i < 8; i++) {
          final a = i * pi / 4;
          final p1 = c + Offset(cos(a), sin(a)) * r * 0.5;
          final p2 = c + Offset(cos(a), sin(a)) * r * 0.66;
          canvas.drawLine(p1, p2, stroke);
        }
        break;
      case Special.colorClear:
        // A bright star to signal "clears a colour".
        _star(canvas, c, r * 0.5, white);
        break;
    }
  }

  void _arrow(Canvas canvas, Offset c, double r, Paint stroke,
      {required bool horizontal}) {
    final len = r * 0.55;
    if (horizontal) {
      canvas.drawLine(c - Offset(len, 0), c + Offset(len, 0), stroke);
      _head(canvas, c + Offset(len, 0), stroke, r, left: false, horizontal: true);
      _head(canvas, c - Offset(len, 0), stroke, r, left: true, horizontal: true);
    } else {
      canvas.drawLine(c - Offset(0, len), c + Offset(0, len), stroke);
      _head(canvas, c + Offset(0, len), stroke, r, left: false, horizontal: false);
      _head(canvas, c - Offset(0, len), stroke, r, left: true, horizontal: false);
    }
  }

  void _head(Canvas canvas, Offset tip, Paint stroke, double r,
      {required bool left, required bool horizontal}) {
    final s = r * 0.24;
    if (horizontal) {
      final dir = left ? -1 : 1;
      canvas.drawLine(tip, tip + Offset(-dir * s, -s), stroke);
      canvas.drawLine(tip, tip + Offset(-dir * s, s), stroke);
    } else {
      final dir = left ? -1 : 1;
      canvas.drawLine(tip, tip + Offset(-s, -dir * s), stroke);
      canvas.drawLine(tip, tip + Offset(s, -dir * s), stroke);
    }
  }

  void _star(Canvas canvas, Offset c, double radius, Paint paint) {
    final path = Path();
    for (int i = 0; i < 10; i++) {
      final a = -pi / 2 + i * pi / 5;
      final rad = i.isEven ? radius : radius * 0.45;
      final p = c + Offset(cos(a), sin(a)) * rad;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant GemPainter old) =>
      old.type != type ||
      old.special != special ||
      old.scale != scale ||
      old.glow != glow;
}
