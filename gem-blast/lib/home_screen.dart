import 'dart:math';
import 'package:flutter/material.dart';
import 'audio_manager.dart';
import 'game_screen.dart';
import 'gem_painter.dart';
import 'levels.dart';
import 'storage.dart';
import 'theme.dart';

/// Animated landing screen: floating gems background, title, high score, a big
/// Play button (opens the level select) and audio settings toggles.
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
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))
      ..repeat();
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

  Future<void> _openLevelSelect() async {
    AudioManager.instance.play('button');
    await Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, a, b) => const LevelSelectScreen(),
        transitionsBuilder: (_, a, b, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
    if (mounted) setState(() {}); // refresh high score / unlocked levels
  }

  @override
  Widget build(BuildContext context) {
    final high = Storage.instance.highScore;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: GameTheme.background),
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) => CustomPaint(
                painter: _FloatingGemsPainter(_gems, _ctrl.value),
                size: Size.infinite,
              ),
            ),
            Positioned(
              top: 12,
              right: 8,
              child: SafeArea(child: _settingsButton()),
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
                    const Text('Match • Cascade • Blast',
                        style: TextStyle(
                            color: GameTheme.textDim,
                            fontSize: 15,
                            letterSpacing: 3)),
                    const SizedBox(height: 16),
                    _highScoreChip(high),
                    const SizedBox(height: 44),
                    _playButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _highScoreChip(int high) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events, color: GameTheme.accent, size: 18),
          const SizedBox(width: 8),
          Text('Best: $high',
              style: const TextStyle(
                  color: GameTheme.textLight,
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
        ],
      ),
    );
  }

  Widget _settingsButton() {
    return IconButton(
      icon: const Icon(Icons.settings, color: GameTheme.textLight),
      onPressed: () {
        AudioManager.instance.play('button');
        showModalBottomSheet(
          context: context,
          backgroundColor: GameTheme.bgMid,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (_) => const _SettingsSheet(),
        );
      },
    );
  }

  Widget _playButton() {
    return GestureDetector(
      onTap: _openLevelSelect,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFFFD54F), Color(0xFFF9A825)]),
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFFFD54F).withValues(alpha: 0.5),
                blurRadius: 24,
                offset: const Offset(0, 8)),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow_rounded, color: Color(0xFF2D1B69), size: 30),
            SizedBox(width: 8),
            Text('PLAY',
                style: TextStyle(
                    color: Color(0xFF2D1B69),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2)),
          ],
        ),
      ),
    );
  }
}

/// Grid of levels; locked levels appear dimmed until the previous one is beaten.
class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final unlocked = Storage.instance.unlockedLevel;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: GameTheme.background),
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: GameTheme.textLight, size: 20),
                  ),
                  const SizedBox(width: 4),
                  Text('Select Level', style: GameTheme.title.copyWith(fontSize: 26)),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: Levels.count,
                  itemBuilder: (context, i) {
                    final lvl = Levels.byIndex(i);
                    final isUnlocked = i <= unlocked;
                    return _levelCard(context, lvl, isUnlocked);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _levelCard(BuildContext context, LevelDef lvl, bool unlocked) {
    return GestureDetector(
      onTap: unlocked
          ? () {
              AudioManager.instance.play('button');
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => GameScreen(level: lvl)),
              );
            }
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: unlocked ? 0.10 : 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: unlocked ? GameTheme.accent.withValues(alpha: 0.6) : Colors.white12,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (unlocked)
              Text('${lvl.displayNumber}',
                  style: const TextStyle(
                      color: GameTheme.textLight,
                      fontSize: 30,
                      fontWeight: FontWeight.w900))
            else
              const Icon(Icons.lock, color: Colors.white38, size: 28),
            const SizedBox(height: 4),
            Text(lvl.name,
                style: TextStyle(
                    color: unlocked ? GameTheme.textDim : Colors.white30,
                    fontSize: 12)),
            const SizedBox(height: 2),
            Text('★ ${lvl.targetScore}',
                style: TextStyle(
                    color: unlocked ? GameTheme.accent : Colors.white24,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet();
  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Settings',
              style: TextStyle(
                  color: GameTheme.textLight,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          SwitchListTile(
            value: AudioManager.instance.sfxEnabled,
            activeThumbColor: GameTheme.accent,
            contentPadding: EdgeInsets.zero,
            title: const Text('Sound effects',
                style: TextStyle(color: GameTheme.textLight)),
            onChanged: (v) {
              setState(() => AudioManager.instance.sfxEnabled = v);
              Storage.instance.setSfxEnabled(v);
              if (v) AudioManager.instance.play('button');
            },
          ),
          SwitchListTile(
            value: AudioManager.instance.musicEnabled,
            activeThumbColor: GameTheme.accent,
            contentPadding: EdgeInsets.zero,
            title: const Text('Music',
                style: TextStyle(color: GameTheme.textLight)),
            onChanged: (v) {
              setState(() {});
              AudioManager.instance.setMusicEnabled(v);
              Storage.instance.setMusicEnabled(v);
            },
          ),
        ],
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
  final double x;
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
      final dx = size.width * g.x + sin((progress + g.phase) * pi * 2) * 20;
      canvas.save();
      canvas.translate(dx, y);
      GemPainter(type: g.type, glow: 0.15).paint(canvas, Size(g.size, g.size));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _FloatingGemsPainter old) => old.t != t;
}
