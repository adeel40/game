import 'dart:math';
import 'package:flutter/material.dart';
import 'game_screen.dart';
import 'gem_painter.dart';
import 'theme.dart';

/// Animated landing screen with a floating gems background, the game title
/// and a big "Play" button.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _rng = Random(7);
  late final List<_FloatingGem> _gems;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _gems = List.generate(
      12,
      (_) => _FloatingGem(
        type: _rng.nextInt(6),
        x: _rng.nextDouble(),
        size: 24 + _rng.nextDouble() * 46,
        speed: 0.3 + _rng.nextDouble() * 0.9,
        phase: _rng.nextDouble(),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: GameTheme.background),
        child: Stack(
          children: [
            // Floating gems background.
            AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) {
                return CustomPaint(
                  painter: _FloatingGemsPainter(_gems, _ctrl.value),
                  size: Size.infinite,
                );
              },
            ),
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _TitleGemRow(),
                    const SizedBox(height: 24),
                    Text('GEM BLAST', style: GameTheme.title),
                    const SizedBox(height: 8),
                    const Text(
                      'Match • Cascade • Blast',
                      style: TextStyle(
                        color: GameTheme.textDim,
                        fontSize: 15,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 56),
                    _playButton(context),
                    const SizedBox(height: 16),
                    const Text(
                      '25 moves • chase your high score',
                      style: TextStyle(color: GameTheme.textDim, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _playButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 400),
            pageBuilder: (_, a, b) => const GameScreen(),
            transitionsBuilder: (_, a, b, child) =>
                FadeTransition(opacity: a, child: child),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD54F), Color(0xFFF9A825)],
          ),
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD54F).withValues(alpha: 0.5),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow_rounded,
                color: Color(0xFF2D1B69), size: 30),
            SizedBox(width: 8),
            Text(
              'PLAY',
              style: TextStyle(
                color: Color(0xFF2D1B69),
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleGemRow extends StatelessWidget {
  const _TitleGemRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < 5; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SizedBox(
                width: 44,
                height: 44,
                child: CustomPaint(painter: GemPainter(type: i, glow: 0.4)),
              ),
            ),
        ],
      ),
    );
  }
}

class _FloatingGem {
  _FloatingGem({
    required this.type,
    required this.x,
    required this.size,
    required this.speed,
    required this.phase,
  });
  final int type;
  final double x; // 0..1 horizontal position
  final double size;
  final double speed;
  final double phase;
}

class _FloatingGemsPainter extends CustomPainter {
  _FloatingGemsPainter(this.gems, this.t);
  final List<_FloatingGem> gems;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final g in gems) {
      final progress = (t * g.speed + g.phase) % 1.0;
      final y = size.height * (1.0 - progress);
      final dx = size.width * g.x +
          sin((progress + g.phase) * pi * 2) * 20;
      canvas.save();
      canvas.translate(dx, y);
      final painter = GemPainter(type: g.type, glow: 0.15);
      painter.paint(canvas, Size(g.size, g.size));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _FloatingGemsPainter old) => old.t != t;
}
