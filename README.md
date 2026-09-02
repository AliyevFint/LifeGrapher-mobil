# LifeGrapher Mobile

LifeGrapher is now a Flutter-only mobile app for tracking daily nutrition, hydration, sleep, and personal goals. The former Next.js web application has been removed.

## Current MVP Features

- E-poçt/şifrə, Google və Apple ilə giriş
- Firebase Authentication ilə hesab idarəetməsi
- Manual yemək qeydi: yemək adı, növü, kalori, protein, karbohidrat və yağ
- Yuxu qeydi: yatış/oyanış saatı, avtomatik müddət və 1–5 keyfiyyət balı
- Günlük, həftəlik, aylıq və illik panel görünüşü
- Ayarlardan dəyişdirilə bilən gündəlik kalori və yuxu hədəfləri
- Firebase Firestore-da istifadəçiyə aid, host edilmiş və qalıcı məlumat saxlanması

## Run on an iOS Simulator or Android Emulator

1. Open the `lifegrapher_mobile` directory in VS Code.
2. Start an available iOS Simulator or Android Emulator.
3. Run `flutter pub get` once.
4. Run `flutter run`.

## 3-cü həftə demo axını

1. Yeni hesab yarat və ya mövcud hesabla daxil ol.
2. **Yeməklər** bölməsindən ən azı bir yemək qeydi əlavə et.
3. **Yuxu** bölməsindən yatış, oyanış və keyfiyyət məlumatı ilə bir yuxu qeydi əlavə et.
4. **Panel** bölməsində gündəlik nəticələri gör.
5. Tətbiqi bağlayıb yenidən aç: qeydlər Firestore-dan yenidən yüklənir.

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
