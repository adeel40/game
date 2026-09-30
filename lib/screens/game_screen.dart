import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../game/sound_manager.dart';
import '../models/level.dart';
import '../theme.dart';
import '../widgets/board_view.dart';

/// The main play screen: HUD at the top, animated board in the middle, and
/// win/lose overlays that appear when the level ends.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.level});

  final Level level;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameController _controller;
  bool _endShown = false;
  final GlobalKey<BoardViewState> _boardKey = GlobalKey<BoardViewState>();

  @override
  void initState() {
    super.initState();
    _controller = GameController(widget.level)..addListener(_onChange);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    _controller.dispose();
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    if (_controller.status != GameStatus.playing && !_endShown) {
      _endShown = true;
      // Let the final animation settle before showing the overlay.
      Future<void>.delayed(const Duration(milliseconds: 500), _showEndDialog);
    }
  }

  Future<void> _showEndDialog() async {
    if (!mounted) return;
    final won = _controller.status == GameStatus.won;
    if (won) {
      await _controller.saveProgress();
      SoundManager.instance.win();
    } else {
      SoundManager.instance.lose();
    }

    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _EndDialog(
        won: won,
        score: _controller.score,
        stars: _controller.stars,
        levelNumber: widget.level.number,
        hasNext: widget.level.number < Levels.total,
        onReplay: () {
          Navigator.of(context).pop();
          setState(() {
            _controller.removeListener(_onChange);
            _controller.dispose();
            _controller = GameController(widget.level)..addListener(_onChange);
            _endShown = false;
          });
        },
        onNext: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) =>
                  GameScreen(level: Levels.get(widget.level.number + 1)),
            ),
          );
        },
        onHome: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.background),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              _buildHud(),
              const SizedBox(height: 8),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: BoardView(key: _boardKey, controller: c),
                  ),
                ),
              ),
              _buildHintBar(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHintBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              'Swap two touching gems to line up 3+ of a kind',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _boardKey.currentState?.showHint(),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: AppTheme.accentButton,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lightbulb_rounded,
                      color: Colors.black87, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'HINT',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          Text(
            'Level ${widget.level.number}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              SoundManager.instance.enabled
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              color: Colors.white,
            ),
            tooltip: 'Sound on/off',
            onPressed: () => setState(
              () => SoundManager.instance.enabled =
                  !SoundManager.instance.enabled,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHud() {
    final c = _controller;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatChip(
                label: 'SCORE',
                value: '${c.score}',
                icon: Icons.stars_rounded,
              ),
              _StatChip(
                label: 'MOVES',
                value: '${c.movesLeft}',
                icon: Icons.swipe_rounded,
                highlight: c.movesLeft <= 5,
              ),
              _StatChip(
                label: 'TARGET',
                value: '${widget.level.targetScore}',
                icon: Icons.flag_rounded,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: c.targetProgress,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(
                c.targetProgress >= 1.0 ? Colors.greenAccent : AppTheme.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: highlight
            ? Colors.redAccent.withValues(alpha: 0.25)
            : AppTheme.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight
              ? Colors.redAccent.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppTheme.accent),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _EndDialog extends StatelessWidget {
  const _EndDialog({
    required this.won,
    required this.score,
    required this.stars,
    required this.levelNumber,
    required this.hasNext,
    required this.onReplay,
    required this.onNext,
    required this.onHome,
  });

  final bool won;
  final int score;
  final int stars;
  final int levelNumber;
  final bool hasNext;
  final VoidCallback onReplay;
  final VoidCallback onNext;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2D1B4E), Color(0xFF1A1035)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              won ? 'LEVEL CLEAR!' : 'OUT OF MOVES',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: won ? AppTheme.accent : Colors.redAccent,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            if (won)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        i < stars ? Icons.star_rounded : Icons.star_border_rounded,
                        size: 44,
                        color: i < stars
                            ? AppTheme.accent
                            : Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 16),
            Text(
              'Score: $score',
              style: const TextStyle(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _DialogButton(
                  icon: Icons.home_rounded,
                  onTap: onHome,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                const SizedBox(width: 12),
                _DialogButton(
                  icon: Icons.replay_rounded,
                  onTap: onReplay,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                if (won && hasNext) ...[
                  const SizedBox(width: 12),
                  _DialogButton(
                    icon: Icons.arrow_forward_rounded,
                    onTap: onNext,
                    gradient: AppTheme.accentButton,
                    iconColor: Colors.black87,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.icon,
    required this.onTap,
    this.color,
    this.gradient,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final Gradient? gradient;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: color,
          gradient: gradient,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 28),
      ),
    );
  }
}
