# BYPT Calculator

A modern, responsive calculator app built with Flutter. It supports a basic and scientific keypad, animated UI, and a persistent calculation history with a slide-in drawer.

## Features

- Basic operations: +, −, ×, ÷, %, parentheses, decimal
- Scientific functions: sin, cos, tan, log, ln, sqrt, power, constants (π, e)
- Animated UI/UX with Material 3
- Persistent history (local storage) using `shared_preferences`
- Slide-in history drawer:
  - View previous calculations (expression + result + timestamp)
  - Tap to restore expression/result into the calculator
  - Clear all history
- Responsive layout:
  - Mobile: stacked layout (display → scientific panel → basic pad)
  - Web/desktop: optional scientific sidebar and centered card shell on web

## Screenshots

(Add screenshots or GIFs here if desired)

## Tech Stack

- Flutter 3.x
- Dart 3.x
- Packages: `math_expressions`, `shared_preferences`, `flutter_native_splash`

## Project Structure

- `lib/main.dart`: App, calculator UI, history drawer, and persistence
- `assets/`: Logos and images
- `test/`: Widget tests for calculator behavior and history

## Getting Started

1) Prerequisites
- Flutter SDK installed (`flutter --version`)
- Xcode (iOS) and/or Android Studio SDKs (Android)

2) Install dependencies

```bash
flutter pub get
```

3) Run the app

```bash
# Android
a) Start an Android emulator or connect a device
b) flutter run -d android

# iOS
a) Open an iOS simulator or connect a device
b) flutter run -d ios

# Web
flutter run -d chrome
```

## Usage Tips

- The history button in the AppBar opens the slide-in history drawer.
- Tap any entry in history to restore its expression/result.
- Use the scientific icon in the AppBar to toggle the scientific keypad.

## Tests

This project includes an automated widget test suite.

Run tests:

```bash
flutter test -r expanded
```

What’s covered:
- Evaluations (addition, percent, scientific `sin(0)`)
- Backspace and clear-all interactions
- History behavior (append on evaluate, open drawer, tap-to-restore, clear history)

## Implementation Notes

- Expression parsing/evaluation is handled by `math_expressions`.
- Percent handling: `%` is normalized to `/100` before evaluation.
- Number formatting trims trailing zeros while preserving precision and avoiding spurious `.0`.
- History is stored as a list of JSON strings under the key `calc_history_v1`.

## Build & Release

Android (Debug/Release):
```bash
flutter build apk --release
```

iOS:
```bash
flutter build ios --release
```

Web:
```bash
flutter build web
```

Artifacts are generated under `build/`.

## Accessibility

- Buttons are large with clear contrast; animations are subtle and fast.

## License

MIT (or your preferred license)
