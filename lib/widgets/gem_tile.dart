import 'package:flutter/material.dart';

import '../models/gem.dart';

/// A single rendered gem: a rounded gradient jewel with a glossy highlight,
/// soft glow, and its identifying glyph. Draws crisply at any size.
class GemTile extends StatelessWidget {
  const GemTile({
    super.key,
    required this.gem,
    required this.size,
    this.selected = false,
    this.hint = false,
  });

  final Gem gem;
  final double size;
  final bool selected;
  final bool hint;

  @override
  Widget build(BuildContext context) {
    final inset = size * 0.08;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      width: size,
      height: size,
      padding: EdgeInsets.all(inset),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 160),
        scale: selected ? 1.12 : 1.0,
        curve: Curves.easeOutBack,
        child: CustomPaint(
          painter: _GemPainter(
            gradient: gem.type.gradient,
            glow: gem.type.glowColor,
            selected: selected,
            hint: hint,
            power: gem.power,
          ),
          child: Center(
            child: Icon(
              gem.type.icon,
              size: (size - inset * 2) * 0.42,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ),
      ),
    );
  }
}

class _GemPainter extends CustomPainter {
  _GemPainter({
    required this.gradient,
    required this.glow,
    required this.selected,
    required this.hint,
    required this.power,
  });

  final List<Color> gradient;
  final Color glow;
  final bool selected;
  final bool hint;
  final GemPower power;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(size.width * 0.28);
    final rrect = RRect.fromRectAndRadius(rect, radius);

    // Outer glow (stronger when selected or hinted).
    final glowStrength = selected ? 0.65 : (hint ? 0.5 : 0.28);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = glow.withValues(alpha: glowStrength)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          size.width * (selected ? 0.22 : 0.14),
        ),
    );

    // Main body gradient.
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ).createShader(rect),
    );

    // Facet: a darker triangle at the bottom-right for a 3D jewel feel.
    final facet = Path()
      ..moveTo(size.width, size.height * 0.35)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.35, size.height)
      ..close();
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawPath(
      facet,
      Paint()..color = Colors.black.withValues(alpha: 0.16),
    );

    // Glossy highlight in the top-left.
    final highlight = Path()
      ..moveTo(size.width * 0.14, size.height * 0.12)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.05,
        size.width * 0.82,
        size.height * 0.18,
      )
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.32,
        size.width * 0.14,
        size.height * 0.12,
      )
      ..close();
    canvas.drawPath(
      highlight,
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
    canvas.restore();

    // Border, brighter when selected.
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 3.0 : 1.5
        ..color = Colors.white.withValues(alpha: selected ? 0.9 : 0.4),
    );

    // Power indicator ring.
    if (power != GemPower.none) {
      canvas.drawRRect(
        rrect.deflate(size.width * 0.06),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = Colors.white.withValues(alpha: 0.85),
      );
    }
  }

  @override
  bool shouldRepaint(_GemPainter old) =>
      old.selected != selected ||
      old.hint != hint ||
      old.gradient != gradient ||
      old.power != power;
}
