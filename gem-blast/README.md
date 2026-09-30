# 💎 Gem Blast

An addictive **Match-3 puzzle game** built with **Flutter** for Android, featuring
custom-painted jewel graphics, smooth swap/cascade animations, **special power-up
gems**, **objective-based levels**, **sound & music**, and a **persistent high
score**. Think Candy Crush — but hand-crafted with `CustomPainter` (no image or
audio assets; every visual is drawn and every sound is synthesised at runtime).

## ✨ Features

- **Custom jewel graphics** — 6 gem types, each drawn with radial gradients, a
  glossy highlight, specular dot and a soft glow (`GemPainter`).
- **Special power-up gems**
  - Match **4 in a row/column** → a **line-blast** gem (clears its whole row or column).
  - Match in an **L / T shape** → a **bomb** (clears a 3×3 area).
  - Match **5** → a **color-clear** gem (removes every gem of one colour).
  - Power-ups chain with each other for huge combos.
- **Objective-based levels** — 10 hand-tuned levels, each with a target score
  and a limited move budget. Beat one to unlock the next.
- **Level select + progression** — locked/unlocked level grid, saved between sessions.
- **Sound & music** — synthesised SFX (select, swap, match, cascade, power-up,
  level-up, game-over) and a looping background melody. Toggle each in settings.
- **Persistent high score** — your best run is saved with `shared_preferences`.
- **Juicy animations** — sliding swaps, match pop-out, gravity drops, cascades
  with a rising combo multiplier.
- **Haptics** and a polished dark jewel theme with an animated floating-gems menu.

## 🎮 How to play

- **Tap** two adjacent gems to swap them, or **swipe** a gem in a direction.
- Line up **3+** of the same gem to clear them; **4+** or special shapes create
  power-up gems — swap a power-up to detonate it.
- Reach the **target score** before you run out of **moves** to clear the level.

## 🏗️ Project structure

| File | Responsibility |
|------|----------------|
| `lib/main.dart` | App entry, storage/audio init, theme, orientation lock |
| `lib/theme.dart` | Colors, gem palettes, gradients, text styles |
| `lib/game_board.dart` | Match-3 logic + power-up creation/detonation |
| `lib/gem_painter.dart` | Custom painter for normal & special gems |
| `lib/game_screen.dart` | Board, gestures, animation pipeline, objectives, HUD |
| `lib/home_screen.dart` | Menu, level select, settings sheet |
| `lib/levels.dart` | Level definitions (moves, target score, colours) |
| `lib/audio_manager.dart` | Runtime WAV synthesis + SFX/music playback |
| `lib/storage.dart` | Persistent high score, unlocked level, settings |
| `test/game_board_test.dart` | Unit tests for the core game logic |

## 🚀 Run & build

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.x)
and the Android SDK.

```bash
cd gem-blast
flutter pub get

flutter run                 # play on a device/emulator
flutter analyze             # static analysis (clean)
flutter test                # unit tests (9 passing)

flutter build apk --release # → build/app/outputs/flutter-apk/app-release.apk
flutter build appbundle     # → Play Store bundle
```

Install on a device:

```bash
flutter install
# or
adb install build/app/outputs/flutter-apk/app-release.apk
```

## 🛠️ Tech

- **Flutter / Dart** — custom-rendered graphics, no game engine.
- `audioplayers` — plays runtime-synthesised WAV sound effects & music.
- `shared_preferences` — persistent high score, progress and settings.
- No bundled image or audio assets — everything is generated in code.
