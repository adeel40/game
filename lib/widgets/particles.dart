import 'dart:math';

import 'package:flutter/material.dart';

/// A short-lived burst of colored particles played when gems are cleared.
/// Purely decorative; drives itself with its own controller and removes
/// itself via [onDone].
class ParticleBurst extends StatefulWidget {
  const ParticleBurst({
    super.key,
    required this.color,
    required this.size,
    this.onDone,
  });

  final Color color;
  final double size;
  final VoidCallback? onDone;

  @override
  State<ParticleBurst> createState() => _ParticleBurstState();
}

class _ParticleBurstState extends State<ParticleBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _particles = List.generate(10, (_) {
      final angle = rng.nextDouble() * 2 * pi;
      final speed = 0.4 + rng.nextDouble() * 0.6;
      return _Particle(
        dx: cos(angle) * speed,
        dy: sin(angle) * speed,
        radius: widget.size * (0.05 + rng.nextDouble() * 0.06),
      );
    });
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward().whenComplete(() => widget.onDone?.call());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _ParticlePainter(
            particles: _particles,
            progress: _c.value,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}

class _Particle {
  _Particle({required this.dx, required this.dy, required this.radius});
  final double dx;
  final double dy;
  final double radius;
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.color,
  });

  final List<_Particle> particles;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final travel = size.width * 0.9;
    final paint = Paint()
      ..color = color.withValues(alpha: (1 - progress).clamp(0.0, 1.0));
    for (final p in particles) {
      final pos = center +
          Offset(p.dx * travel * progress, p.dy * travel * progress);
      canvas.drawCircle(pos, p.radius * (1 - progress * 0.4), paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}
