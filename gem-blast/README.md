# 💎 Gem Blast

An addictive **Match-3 puzzle game** built with **Flutter** for Android, featuring
custom-painted jewel graphics, smooth swap/cascade animations, combos and haptic
feedback. Think Candy Crush — but hand-crafted with `CustomPainter` (no image
assets, everything is drawn with gradients and glow).

## ✨ Features

- **Custom jewel graphics** — 6 gem types, each drawn with radial gradients, a
  glossy highlight, specular dot and a soft glow (`GemPainter`).
- **Juicy animations** — sliding swaps, match pop-out, gravity drops with a
  lively ease-out, and chain **cascades** that increase your combo multiplier.
- **Combos & scoring** — every cascade step multiplies your points.
- **Smart board** — starts with no free matches, reshuffles automatically when
  no moves remain, and validates swaps before committing.
- **Haptics** — tactile feedback on selection, swap, match and invalid moves.
- **Polished UI** — animated floating-gems home screen, portrait-locked, dark
  jewel theme.

## 🎮 How to play

- **Tap** two adjacent gems to swap them, or **swipe** a gem in a direction.
- Line up **3 or more** of the same gem horizontally or vertically to clear them.
- Clearing gems drops new ones from the top — chain reactions build **combos**.
- You have **25 moves**. Chase the highest score!

## 🏗️ Project structure

| File | Responsibility |
|------|----------------|
| `lib/main.dart` | App entry, theme, orientation lock |
| `lib/theme.dart` | Colors, gem palettes, gradients, text styles |
| `lib/game_board.dart` | Pure Match-3 logic (matches, gravity, refill, reshuffle) |
| `lib/gem_painter.dart` | Custom painter that draws a single jewel |
| `lib/game_screen.dart` | Board rendering, gestures, animation pipeline, HUD |
| `lib/home_screen.dart` | Animated landing screen with floating gems |
| `test/game_board_test.dart` | Unit tests for the core game logic |

## 🚀 Run & build

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.x).

```bash
# Fetch dependencies
flutter pub get

# Run on a connected device / emulator
flutter run

# Analyze & test
flutter analyze
flutter test

# Build a release APK (output: build/app/outputs/flutter-apk/app-release.apk)
flutter build apk --release

# Or an app bundle for the Play Store
flutter build appbundle --release
```

Install the APK on a device:

```bash
flutter install
# or
adb install build/app/outputs/flutter-apk/app-release.apk
```

## 🛠️ Tech

- **Flutter / Dart** — cross-platform, custom-rendered graphics.
- No external game engine or image assets — all visuals are drawn at runtime.
