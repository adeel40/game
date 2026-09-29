import 'dart:math';

import 'package:flutter/material.dart';

import '../models/gem.dart';
import '../theme.dart';
import '../widgets/gem_tile.dart';
import 'level_select_screen.dart';

/// The landing screen: animated floating gems, a big title, and a Play button.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.background),
        child: Stack(
          children: [
            // Floating decorative gems in the background.
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(
                size: MediaQuery.of(context).size,
                painter: _FloatingGemsPainter(_c.value),
              ),
            ),
            SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  _buildTitleGems(),
                  const SizedBox(height: 24),
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        AppTheme.accentButton.createShader(bounds),
                    child: const Text(
                      'GEM CRUSH',
                      style: TextStyle(
                        fontSize: 46,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Match • Cascade • Conquer',
                    style: TextStyle(
                      fontSize: 15,
                      letterSpacing: 1.5,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const Spacer(),
                  _PlayButton(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LevelSelectScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleGems() {
    const types = [
      GemType.ruby,
      GemType.emerald,
      GemType.sapphire,
      GemType.amber,
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < types.length; i++)
          AnimatedBuilder(
            animation: _c,
            builder: (context, child) {
              final bob = sin((_c.value * 2 * pi) + i) * 6;
              return Transform.translate(
                offset: Offset(0, bob),
                child: child,
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GemTile(gem: Gem(id: -i - 1, type: types[i]), size: 56),
            ),
          ),
      ],
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 18),
        decoration: BoxDecoration(
          gradient: AppTheme.accentButton,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withValues(alpha: 0.5),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow_rounded, color: Colors.black87, size: 28),
            SizedBox(width: 8),
            Text(
              'PLAY',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingGemsPainter extends CustomPainter {
  _FloatingGemsPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(7);
    for (var i = 0; i < 14; i++) {
      final baseX = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final r = 8.0 + rng.nextDouble() * 22;
      final drift = sin((t * 2 * pi) + i) * 18;
      final colors = GemType.values[i % GemType.values.length].gradient;
      canvas.drawCircle(
        Offset(baseX + drift, baseY + cos((t * 2 * pi) + i) * 12),
        r,
        Paint()
          ..color = colors.first.withValues(alpha: 0.10)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  @override
  bool shouldRepaint(_FloatingGemsPainter old) => old.t != t;
}
