# LifeGrapher Mobile

LifeGrapher is now a Flutter-only mobile app for tracking daily nutrition, hydration, sleep, and personal goals. The former Next.js web application has been removed.

## Current Features

- Azərbaycan, İngilis, Türk, Alman və Rus dilləri. Giriş ekranından və **Ayarlar → Dil** bölməsindən dəyişdirilir; seçim cihazda saxlanır. Tarix/saat pəncərələri, rəqəmlər, formalar və bildirişlər seçilən dilə uyğun göstərilir.

- Firebase Authentication ilə e-poçt/şifrə, Google və Apple giriş interfeysləri.
- Admin hesabı üçün `34555` giriş ID-si; digər hesablara cihazda avtomatik ID.
- Yemək adı, növü, kalori və makroların qeyd edilməsi.
- Yuxu saatları, müddət və 1–5 keyfiyyət balı.
- Gündəlik/həftəlik/aylıq/illik panel və dəyişdirilə bilən hədəflər.
- Yemək, yuxu, profil və hədəflər tətbiqin telefon yaddaşındakı qovluğuna yazılır. Saxlama server cavabını gözləmir; uğur yalnız disk yazısı tamamlananda göstərilir.
- Məlumatlar Firebase UID-si üzrə ayrı fayllarda saxlanır və tətbiq yenidən açıldıqda qalır.
- Əvvəlki Firestore versiyasının cihazda keşlənmiş yemək/yuxu qeydləri bir dəfə yerli yaddaşa daşınır.

Yeni hesaba giriş üçün internet lazımdır. Yerli ID başqa cihazda tanınmırsa, e-poçtla daxil olun. Yerli qeydlər cihazlar arasında sinxronlaşmır; tətbiqi silmək yerli məlumatları silə bilər.

## Run

```bash
cd lifegrapher_mobile
flutter pub get
flutter run
```

`path_provider_foundation` və `path_provider_android` versiyaları layihənin mövcud Flutter/native-assets alətləri ilə uyğunluq üçün sabitlənib.

## 3-cü həftə

İstifadəçinin son istəyinə əsasən saxlama telefon yaddaşına keçirilib. Bu rejim müqavilədəki hosted verilənlər bazası tələbini ödəmir. Bulud bazası qurulması və canlı nümayiş tamamlanmış kimi qeyd edilmir. Tarixi yoxlamalar: [yoxlama qeydi](notes/week-3-verification.md).

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
