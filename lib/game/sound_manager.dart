import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Central place for all game audio + haptics. Uses short generated WAV
/// assets played through `audioplayers`, plus light haptic feedback so the
/// game feels responsive even with the volume off.
///
/// Sound can be muted globally via [enabled]; failures to play (e.g. a device
/// with no audio) are swallowed so they never crash gameplay.
class SoundManager {
  SoundManager._();
  static final SoundManager instance = SoundManager._();

  bool enabled = true;

  // A small pool of players so overlapping effects (rapid cascades) don't cut
  // each other off.
  final List<AudioPlayer> _pool = List.generate(4, (_) => AudioPlayer());
  int _next = 0;

  AudioPlayer get _player {
    final p = _pool[_next];
    _next = (_next + 1) % _pool.length;
    return p;
  }

  Future<void> _play(String asset, {double volume = 1.0}) async {
    if (!enabled) return;
    try {
      final player = _player;
      await player.stop();
      await player.play(AssetSource(asset), volume: volume);
    } catch (_) {
      // Ignore audio errors so they never interrupt gameplay.
    }
  }

  /// A gem was selected / tapped.
  Future<void> select() async {
    HapticFeedback.selectionClick();
    await _play('sounds/tap.wav', volume: 0.5);
  }

  /// A swap that didn't form a match.
  Future<void> invalid() async {
    HapticFeedback.lightImpact();
    await _play('sounds/invalid.wav', volume: 0.6);
  }

  /// A group of gems cleared. [cascade] rises with each chained clear so the
  /// pitch/energy climbs during a combo.
  Future<void> match(int cascade) async {
    HapticFeedback.mediumImpact();
    final asset = cascade >= 3
        ? 'sounds/match3.wav'
        : (cascade == 2 ? 'sounds/match2.wav' : 'sounds/match1.wav');
    await _play(asset, volume: 0.9);
  }

  Future<void> win() async {
    HapticFeedback.heavyImpact();
    await _play('sounds/win.wav');
  }

  Future<void> lose() async {
    HapticFeedback.heavyImpact();
    await _play('sounds/lose.wav');
  }

  void dispose() {
    for (final p in _pool) {
      p.dispose();
    }
  }
}
