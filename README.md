# 💎 Gem Crush

An addictive **Match-3 puzzle game** for Android, built with Flutter. Swap
adjacent gems to line up three or more of a kind, trigger cascading combos, and
race to beat each level's target score before you run out of moves.

<p align="center">
  <i>Match • Cascade • Conquer</i>
</p>

---

## ✨ Features

- **Satisfying Match-3 gameplay** — tap-to-swap or swipe adjacent gems.
- **Cascading combos** — chain reactions score more with every cascade layer.
- **30 levels** with a smooth difficulty curve (more gem types, fewer moves,
  higher targets as you progress).
- **Star ratings** — earn 1–3 stars per level based on your score.
- **Progress saving** — unlocked levels, best scores, and stars persist between
  sessions (via `shared_preferences`).
- **Polished visuals** — gradient jewels with glossy highlights, glow, soft
  facets, particle bursts on every clear, and fluid fall/refill animations.
- **No dead boards** — the board auto-reshuffles if no moves remain, and starts
  with no accidental pre-matches.
- **Portrait-locked, offline, no ads, no tracking.**

## 🎮 How to play

1. Tap a gem to select it, then tap an adjacent gem to swap — or **swipe** a gem
   toward its neighbor.
2. A swap is only allowed if it forms a line of **3+ matching gems**.
3. Matched gems clear, everything above **falls down**, and new gems drop in —
   which can trigger **cascades** for bonus points.
4. Reach the **target score** before you run out of **moves** to clear the level
   and earn stars.

**Scoring:** each cleared gem is worth 60 points, larger matches add a bonus,
and every cascade layer multiplies the points earned that turn.

## 🗂 Project structure

```
gem_crush/
├── lib/
│   ├── main.dart                 # App entry, theme, portrait lock
│   ├── theme.dart                # Shared palette & gradients
│   ├── models/
│   │   ├── gem.dart              # GemType (colors/icons), GemPower, Gem
│   │   └── level.dart            # Level definitions + procedural Levels.get()
│   ├── game/
│   │   ├── board.dart            # Pure game engine: matching, cascades, refill
│   │   └── game_controller.dart  # Live state (score/moves/status) + persistence
│   ├── widgets/
│   │   ├── gem_tile.dart         # CustomPainter jewel (gradient/glow/facet)
│   │   ├── particles.dart        # Particle burst effect
│   │   └── board_view.dart       # Animated board + gesture handling
│   └── screens/
│       ├── home_screen.dart      # Animated landing screen
│       ├── level_select_screen.dart
│       └── game_screen.dart      # HUD + board + win/lose dialogs
├── test/
│   └── board_test.dart           # Engine unit tests
└── android/                      # Android build config
```

The **game engine** (`board.dart`) is deliberately UI-free and fully unit
tested, so the rules can be verified independently of Flutter.

---

## 🛠 Building the APK

> **Note:** This project was authored in an environment without the Flutter SDK,
> so the APK has **not** been pre-built. Build it locally with the steps below.
> All source, Android config, and launcher icons are included and ready.

### Prerequisites

- **Flutter SDK 3.27 or newer** (stable channel) —
  https://docs.flutter.dev/get-started/install
  The UI uses the current `Color.withValues()` API (Flutter 3.27+). On older
  Flutter, replace `withValues(alpha: x)` with `withOpacity(x)` and lower the
  `environment:` constraint in `pubspec.yaml`.
- **Android toolchain** — Android Studio or the command-line SDK + a JDK.
- Verify your setup: `flutter doctor`

### 1. Fetch dependencies

```bash
cd gem_crush
flutter pub get
```

If Flutter reports missing platform files (e.g. the Gradle wrapper jar), let it
regenerate them without touching the source:

```bash
flutter create . --platforms=android --project-name gem_crush
flutter pub get
```

### 2. Run in debug on a device/emulator

```bash
flutter run
```

### 3. Build a release APK

```bash
flutter build apk --release
```

The APK is written to:

```
build/app/outputs/flutter-apk/app-release.apk
```

Install it on a connected device with:

```bash
flutter install
# or
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Optional: split per-ABI APKs (smaller downloads)

```bash
flutter build apk --release --split-per-abi
```

### Optional: Play Store bundle

```bash
flutter build appbundle --release
```

> **Signing:** for a quick local build the release type is signed with the debug
> key (see `android/app/build.gradle`). Before publishing to the Play Store,
> create a proper upload keystore and wire it up via `android/key.properties`
> per the [Flutter signing guide](https://docs.flutter.dev/deployment/android#signing-the-app).

---

## ✅ Running the tests

The core engine has unit tests covering board generation, swap validation,
cascades, deadlock handling, and level difficulty:

```bash
flutter test
```

---

## 🎨 Customizing

- **Gem colors / icons:** edit `GemTypeVisuals` in `lib/models/gem.dart`.
- **Difficulty curve:** tune `Levels.get()` in `lib/models/level.dart`
  (moves, target score, grid size, number of gem types).
- **Scoring:** adjust the formula in `Board.clearMatches()` in
  `lib/game/board.dart`.
- **App theme / background:** `lib/theme.dart`.
- **Launcher icon:** replace the PNGs under
  `android/app/src/main/res/mipmap-*/ic_launcher.png` (or use the
  [`flutter_launcher_icons`](https://pub.dev/packages/flutter_launcher_icons)
  package for a one-command regen).

## 💡 Ideas for future polish

- Sound effects & background music (e.g. the `audioplayers` package).
- Special gems: the model already has `GemPower.rocket` / `GemPower.bomb`
  hooks ready to wire up for 4- and 5-in-a-row matches.
- Move hints / shuffle button, a timer mode, and daily challenges.

---

Built with Flutter 💙
