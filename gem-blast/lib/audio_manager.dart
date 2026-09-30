import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Handles all game audio. To keep the project asset-free, every sound effect
/// is a short tone (or chord/sweep) synthesised into a WAV byte buffer at
/// startup and played from memory. Background music is a gentle looping
/// arpeggio built the same way.
///
/// Users can toggle SFX and music independently via [sfxEnabled]/[musicEnabled].
class AudioManager {
  AudioManager._();
  static final AudioManager instance = AudioManager._();

  static const int _sampleRate = 44100;

  bool sfxEnabled = true;
  bool musicEnabled = true;

  final AudioPlayer _sfxPlayer = AudioPlayer(playerId: 'sfx')
    ..setReleaseMode(ReleaseMode.stop);
  final AudioPlayer _musicPlayer = AudioPlayer(playerId: 'music')
    ..setReleaseMode(ReleaseMode.loop);

  final Map<String, Uint8List> _cache = {};
  bool _initialised = false;

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;
    await _sfxPlayer.setPlayerMode(PlayerMode.lowLatency);
    await _sfxPlayer.setVolume(0.6);
    await _musicPlayer.setVolume(0.28);

    // Pre-synthesise the effects we use.
    _cache['select'] = _tone(660, 0.06, wave: _Wave.sine);
    _cache['swap'] = _sweep(440, 660, 0.10);
    _cache['invalid'] = _sweep(300, 180, 0.16, wave: _Wave.square);
    _cache['match'] = _chord([523, 659, 784], 0.16);
    _cache['cascade'] = _chord([659, 880, 1046], 0.18);
    _cache['powerup'] = _sweep(600, 1200, 0.22, wave: _Wave.saw);
    _cache['levelup'] = _arpeggio([523, 659, 784, 1046], 0.10);
    _cache['gameover'] = _sweep(500, 120, 0.6, wave: _Wave.saw);
    _cache['button'] = _tone(720, 0.05, wave: _Wave.sine);
  }

  Future<void> play(String name, {double volume = 0.6}) async {
    if (!sfxEnabled) return;
    final data = _cache[name];
    if (data == null) return;
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(BytesSource(data), volume: volume);
    } catch (_) {
      // Audio is best-effort; never let a sound failure break gameplay.
    }
  }

  Future<void> startMusic() async {
    if (!musicEnabled) return;
    try {
      final loop = _musicLoop();
      await _musicPlayer.stop();
      await _musicPlayer.play(BytesSource(loop), volume: 0.28);
    } catch (_) {}
  }

  Future<void> stopMusic() async {
    try {
      await _musicPlayer.stop();
    } catch (_) {}
  }

  Future<void> setMusicEnabled(bool enabled) async {
    musicEnabled = enabled;
    if (enabled) {
      await startMusic();
    } else {
      await stopMusic();
    }
  }

  void dispose() {
    _sfxPlayer.dispose();
    _musicPlayer.dispose();
  }

  // ---- Tone synthesis helpers -------------------------------------------

  Uint8List _tone(double freq, double seconds, {_Wave wave = _Wave.sine}) {
    return _render(seconds, (t) => _sample(wave, freq, t) * _envelope(t, seconds));
  }

  Uint8List _sweep(double f0, double f1, double seconds,
      {_Wave wave = _Wave.sine}) {
    return _render(seconds, (t) {
      final k = t / seconds;
      final f = f0 + (f1 - f0) * k;
      return _sample(wave, f, t) * _envelope(t, seconds);
    });
  }

  Uint8List _chord(List<int> freqs, double seconds) {
    return _render(seconds, (t) {
      double v = 0;
      for (final f in freqs) {
        v += _sample(_Wave.sine, f.toDouble(), t);
      }
      return (v / freqs.length) * _envelope(t, seconds);
    });
  }

  Uint8List _arpeggio(List<int> freqs, double perNote) {
    final total = perNote * freqs.length;
    return _render(total, (t) {
      final idx = (t / perNote).floor().clamp(0, freqs.length - 1);
      final local = t - idx * perNote;
      return _sample(_Wave.sine, freqs[idx].toDouble(), t) *
          _envelope(local, perNote);
    });
  }

  /// A short, softly looping background melody.
  Uint8List _musicLoop() {
    const perNote = 0.34;
    final notes = [392, 494, 587, 494, 440, 523, 659, 523];
    final bass = [196, 196, 220, 220, 174, 174, 196, 196];
    final total = perNote * notes.length;
    return _render(total, (t) {
      final idx = (t / perNote).floor() % notes.length;
      final local = t - (t / perNote).floor() * perNote;
      final lead = _sample(_Wave.sine, notes[idx].toDouble(), t) *
          _envelope(local, perNote) *
          0.6;
      final low = _sample(_Wave.sine, bass[idx].toDouble(), t) * 0.4;
      return (lead + low) * 0.7;
    });
  }

  double _sample(_Wave wave, double freq, double t) {
    final phase = 2 * pi * freq * t;
    switch (wave) {
      case _Wave.sine:
        return sin(phase);
      case _Wave.square:
        return sin(phase) >= 0 ? 0.7 : -0.7;
      case _Wave.saw:
        final p = (freq * t) % 1.0;
        return (2 * p - 1) * 0.7;
    }
  }

  // Simple attack/decay envelope to avoid clicks.
  double _envelope(double t, double dur) {
    const attack = 0.008;
    final release = dur * 0.5;
    if (t < attack) return t / attack;
    if (t > dur - release) return ((dur - t) / release).clamp(0.0, 1.0);
    return 1.0;
  }

  /// Render a mono 16-bit PCM WAV from a per-sample generator in [-1, 1].
  Uint8List _render(double seconds, double Function(double t) gen) {
    final n = (seconds * _sampleRate).round();
    final bytesPerSample = 2;
    final dataSize = n * bytesPerSample;
    final buffer = BytesBuilder();

    // --- WAV header (44 bytes) ---
    buffer.add(_ascii('RIFF'));
    buffer.add(_le32(36 + dataSize));
    buffer.add(_ascii('WAVE'));
    buffer.add(_ascii('fmt '));
    buffer.add(_le32(16)); // fmt chunk size
    buffer.add(_le16(1)); // PCM
    buffer.add(_le16(1)); // mono
    buffer.add(_le32(_sampleRate));
    buffer.add(_le32(_sampleRate * bytesPerSample)); // byte rate
    buffer.add(_le16(bytesPerSample)); // block align
    buffer.add(_le16(16)); // bits per sample
    buffer.add(_ascii('data'));
    buffer.add(_le32(dataSize));

    // --- Samples ---
    final samples = Int16List(n);
    for (int i = 0; i < n; i++) {
      final t = i / _sampleRate;
      final v = (gen(t) * 0.85).clamp(-1.0, 1.0);
      samples[i] = (v * 32767).round();
    }
    buffer.add(samples.buffer.asUint8List());
    return buffer.toBytes();
  }

  List<int> _ascii(String s) => s.codeUnits;
  List<int> _le16(int v) => [v & 0xFF, (v >> 8) & 0xFF];
  List<int> _le32(int v) =>
      [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF];
}

enum _Wave { sine, square, saw }
