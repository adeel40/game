import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper over [SharedPreferences] for the small amount of persistent
/// state the game needs: the all-time high score, the highest level unlocked,
/// and the audio settings.
class Storage {
  Storage._();
  static final Storage instance = Storage._();

  static const _kHighScore = 'high_score';
  static const _kUnlockedLevel = 'unlocked_level';
  static const _kSfx = 'sfx_enabled';
  static const _kMusic = 'music_enabled';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  int get highScore => _prefs?.getInt(_kHighScore) ?? 0;

  /// Records a new high score if [score] beats the stored one.
  /// Returns true if a new record was set.
  Future<bool> submitScore(int score) async {
    if (score > highScore) {
      await _prefs?.setInt(_kHighScore, score);
      return true;
    }
    return false;
  }

  /// Highest level index the player has unlocked (0-based). Level 0 is always
  /// available.
  int get unlockedLevel => _prefs?.getInt(_kUnlockedLevel) ?? 0;

  Future<void> unlockLevel(int level) async {
    if (level > unlockedLevel) {
      await _prefs?.setInt(_kUnlockedLevel, level);
    }
  }

  bool get sfxEnabled => _prefs?.getBool(_kSfx) ?? true;
  Future<void> setSfxEnabled(bool v) async => _prefs?.setBool(_kSfx, v);

  bool get musicEnabled => _prefs?.getBool(_kMusic) ?? true;
  Future<void> setMusicEnabled(bool v) async => _prefs?.setBool(_kMusic, v);
}
