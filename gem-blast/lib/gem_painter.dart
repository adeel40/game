import 'package:flutter/material.dart';
import 'theme.dart';

/// Draws a single jewel-like gem into the given cell. Each gem type is a
/// rounded gem with a radial gradient body, an inner highlight and a small
/// specular dot for a glossy look. [scale] and [glow] let callers animate the
/// gem popping and glowing during matches.
class GemPainter extends CustomPainter {
  GemPainter({required this.type, this.scale = 1.0, this.glow = 0.0});

  final int type;
  final double scale; // 0..1 pop scale
  final double glow; // 0..1 extra glow when matched/selected

  @override
  void paint(Canvas canvas, Size size) {
    if (type < 0) return;
    final colors = GameTheme.gemGradients[type % GameTheme.gemGradients.length];
    final glowColor = GameTheme.gemGlow[type % GameTheme.gemGlow.length];

    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.shortestSide / 2;
    final r = maxR * 0.82 * scale;
    if (r <= 0) return;

    // Glow halo (selection / match feedback).
    if (glow > 0) {
      final glowPaint = Paint()
        ..color = glowColor.withValues(alpha: 0.55 * glow)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 * glow + 2);
      canvas.drawCircle(center, r * (1.0 + 0.25 * glow), glowPaint);
    }

    final rect = Rect.fromCircle(center: center, radius: r);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(r * 0.42));

    // Drop shadow for depth.
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRRect(rrect.shift(const Offset(0, 3)), shadow);

    // Body gradient.
    final body = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        radius: 1.0,
        colors: [colors[0], colors[1]],
      ).createShader(rect);
    canvas.drawRRect(rrect, body);

    // Subtle facet edge.
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.08
      ..color = Colors.white.withValues(alpha: 0.18);
    canvas.drawRRect(rrect.deflate(r * 0.05), edge);

    // Glossy top highlight.
    final highlight = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.center,
        colors: [
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(rect);
    final hlRect = Rect.fromLTWH(
      center.dx - r * 0.55,
      center.dy - r * 0.7,
      r * 1.1,
      r * 0.7,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(hlRect, Radius.circular(r * 0.4)),
      highlight,
    );

    // Specular dot.
    final spec = Paint()..color = Colors.white.withValues(alpha: 0.85);
    canvas.drawCircle(
      Offset(center.dx - r * 0.3, center.dy - r * 0.35),
      r * 0.12,
      spec,
    );
  }

  @override
  bool shouldRepaint(covariant GemPainter old) =>
      old.type != type || old.scale != scale || old.glow != glow;
}
