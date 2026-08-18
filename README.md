# LifeGrapher Mobile

LifeGrapher is now a Flutter-only mobile app for tracking daily nutrition, hydration, sleep, and personal goals. The former Next.js web application has been removed.

## Features

- Local sign-in/profile setup
- Daily calorie summary and meal logging
- Hydration tracker
- Sleep duration and quality tracker
- Persistent on-device data storage

## Run on an iOS Simulator or Android Emulator

1. Open the `lifegrapher_mobile` directory in VS Code.
2. Start an available iOS Simulator or Android Emulator.
3. Run `flutter pub get` once.
4. Run `flutter run`.

The mobile entry point is `lifegrapher_mobile/lib/main.dart`.

## Deadline Tracking Program

Use this to record what you wrote, when you wrote it, and deadline dates.

```bash
python3 tracker.py add --text "submit mobile proposal" --deadline "2026-08-21 18:00"
python3 tracker.py list
python3 tracker.py edit 1 --text "submit updated mobile proposal"
python3 tracker.py due --days 7
python3 tracker.py history 1
python3 tracker.py done 1
```

All tracked data is saved in `data/entries.json` with timestamps for create/edit/done events.

## Daily Auto-Commit To GitHub

This creates a daily scheduled commit at 21:00 local time whenever there are changes.

```bash
chmod +x scripts/auto_commit.sh scripts/install_daily_commit.sh
./scripts/install_daily_commit.sh
```

Manual run (any time):

```bash
./scripts/auto_commit.sh
```
