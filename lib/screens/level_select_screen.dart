import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../models/level.dart';
import '../theme.dart';
import 'game_screen.dart';

/// A scrollable grid of level tiles. Locked levels are dimmed; cleared levels
/// show their earned stars.
class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  int _unlocked = 1;
  Map<int, int> _stars = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final unlocked = await GameController.unlockedLevel();
    final stars = <int, int>{};
    for (var i = 1; i <= Levels.total; i++) {
      stars[i] = await GameController.starsFor(i);
    }
    if (!mounted) return;
    setState(() {
      _unlocked = unlocked;
      _stars = stars;
      _loading = false;
    });
  }

  Future<void> _openLevel(int number) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GameScreen(level: Levels.get(number))),
    );
    // Refresh progress when returning.
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.background),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Select Level',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: Levels.total,
                        itemBuilder: (context, index) {
                          final number = index + 1;
                          final locked = number > _unlocked;
                          return _LevelTile(
                            number: number,
                            stars: _stars[number] ?? 0,
                            locked: locked,
                            onTap: locked ? null : () => _openLevel(number),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.number,
    required this.stars,
    required this.locked,
    required this.onTap,
  });

  final int number;
  final int stars;
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: locked
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF7D3C98), Color(0xFF5B2C6F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: locked ? Colors.white.withValues(alpha: 0.06) : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: locked ? 0.1 : 0.3),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (locked)
              Icon(Icons.lock,
                  color: Colors.white.withValues(alpha: 0.4), size: 26)
            else
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$number',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 3; i++)
                        Icon(
                          i < stars ? Icons.star : Icons.star_border,
                          size: 12,
                          color: i < stars
                              ? AppTheme.accent
                              : Colors.white.withValues(alpha: 0.3),
                        ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
