# Flutter Bələdçisi — Sıfırdan Başlayanlar Üçün

Bu qeyd LifeGrapher layihəsi üzərindən Flutter-i öyrənmək üçündür.
Hər şey sadə dildə, addım-addım yazılıb.

---

## 1. Layihədə hansı qovluq nəyə yarayır?

```
LifeGrapher(mobil)/
│
├── lifegrapher_mobile/          ← ƏSAS QOVLUQ: bütün mobil tətbiq buradadır
│   │
│   ├── lib/                     ← TƏTBİQİN KODU (Dart dili)
│   │   └── main.dart            ← Tətbiqin başlanğıc nöqtəsi.
│   │                              Bütün ekranlar, rənglər, məlumatlar buradadır.
│   │                              Kod yazanda 90% vaxt bu faylla işləyəcəksən.
│   │
│   ├── assets/                  ← Şəkillər, loqolar, ikonlar
│   │   └── logo.png             ← Tətbiqin loqosu (giriş ekranı + tətbiq ikonu)
│   │
│   ├── test/                    ← Testlər
│   │   └── widget_test.dart     ← Tətbiqin düz işlədiyini yoxlayan test
│   │
│   ├── android/                 ← Android-ə xas fayllar (ikonlar, icazələr)
│   │                              Normalda bura toxunmursan.
│   │
│   ├── ios/                     ← iPhone-a xas fayllar (ikonlar, icazələr)
│   │                              Normalda bura toxunmursan.
│   │
│   ├── build/                   ← Flutter-in özü yaratdığı hazır fayllar.
│   │                              HEÇ VAXT əl ilə dəyişmə, silmə — özü yenilənir.
│   │
│   └── pubspec.yaml             ← TƏTBİQİN "PASPORTU":
│                                  - tətbiqin adı, versiyası
│                                  - hansı paketlərdən (kitabxana) istifadə edir
│                                  - hansı şəkillər (assets) daxildir
│                                  Bu faylı dəyişəndən sonra MÜTLƏQ `flutter pub get` işlət.
│
├── notes/                       ← Sənin qeydlərin (bu fayl da buradadır)
├── data/                        ← tracker.py-nin saxladığı məlumatlar
├── scripts/                     ← GitHub-a avtomatik commit skriptləri
├── logs/                        ← Log faylları
├── github/                      ← tracker.py (deadline izləmə proqramı)
├── schema.prisma                ← Gələcəkdə server bazası üçün sxem (hazırda istifadə olunmur)
└── README.md                    ← Layihə haqqında ümumi məlumat
```

### Qızıl qayda
- Kod yazmaq istəyirsənsə → `lifegrapher_mobile/lib/`
- Şəkil əlavə etmək istəyirsənsə → `lifegrapher_mobile/assets/` + `pubspec.yaml`-da qeyd et
- `build/`, `android/`, `ios/` qovluqlarına toxunma

---

## 2. Ən çox işlədilən komandalar

Bütün komandaları `lifegrapher_mobile` qovluğunun İÇİNDƏ işlət:

```bash
cd lifegrapher_mobile
```

| Komanda | Nə işə yarayır | Nə vaxt işlətməli |
|---|---|---|
| `flutter run` | Tətbiqi simulator-da AÇIR | Hər dəfə tətbiqi görmək istəyəndə |
| `flutter pub get` | Paketləri yükləyir | `pubspec.yaml` dəyişəndən sonra MÜTLƏQ |
| `flutter analyze` | Koddakı səhvləri göstərir | Kod yazdıqdan sonra yoxlamaq üçün |
| `flutter test` | Testləri işə salır | Hər şeyin düz işlədiyini yoxlamaq üçün |
| `flutter build ios --simulator` | iPhone simulator üçün tətbiqi qurur | Simulatorda açmazdan əvvəl |
| `flutter clean` | Köhnə yığılmış faylları TƏMİZLƏYİR | Qəribə xəta olanda: əvvəl clean, sonra pub get |
| `flutter doctor` | Flutter-in düz quraşdığını yoxlayır | Problem olanda ilk iş |
| `flutter devices` | Bağlı cihazları/simulatorları göstərir | Tətbiqi harada açacağını görmək üçün |

### Simulator ilə bağlı komandalar (Mac-də iPhone üçün)

```bash
open -a Simulator                 # Simulator proqramını açır
flutter run                       # Tətbiqi açıq simulator-da işə salır
```

### Tətbiq işləyərkən (flutter run açıqkən) klaviatura düymələri

| Düymə | Nə edir |
|---|---|
| `r` | Hot reload — kodu dəyişib dərhal görmək (ən çox işlədilən!) |
| `R` | Hot restart — tətbiqi sıfırdan başladır |
| `q` | Tətbiqi bağlayır |

---

## 3. Ən çox edilən işlər — addım-addım

### A) Tətbiqi açmaq (hər gün edilən iş)
```bash
cd lifegrapher_mobile
open -a Simulator        # iPhone simulator-u aç
flutter run              # tətbiqi başlat
```

### B) Ekranda nəyisə dəyişmək
1. `lib/main.dart` faylını aç
2. Məsələn, bir yazını dəyiş: `'Sabahın xeyir'` → `'Salam'`
3. Yadda saxla (Cmd+S)
4. Terminalda `r` bas (hot reload) — dəyişiklik dərhal görünür

### C) Yeni şəkil/loqo əlavə etmək
1. Şəkli `assets/` qovluğuna at
2. `pubspec.yaml`-da `assets:` bölməsinə əlavə et:
   ```yaml
   flutter:
     assets:
       - assets/logo.png
       - assets/yeni_sekil.png
   ```
3. `flutter pub get` işlət
4. Kodda istifadə et: `Image.asset('assets/yeni_sekil.png')`

### D) Tətbiq ikonunu dəyişmək
1. Yeni loqonu `assets/logo.png` üzərinə köçür (eyni adda saxla)
2. İşlət:
   ```bash
   dart run flutter_launcher_icons
   flutter build ios --simulator
   ```
3. Tətbiqi yenidən yüklə — ana ekranda yeni ikon görünəcək

### E) Yeni paket (kitabxana) əlavə etmək
Məsələn, internetdən məlumat çəkmək üçün `http` paketi:
1. `pubspec.yaml`-da `dependencies:` altına yaz:
   ```yaml
   dependencies:
     http: ^1.2.0
   ```
2. `flutter pub get` işlət
3. Kodda: `import 'package:http/http.dart' as http;`

### F) Xəta çıxanda nə etməli?
1. Terminaldakı qırmızı yazını oxu — adətən fayl adı və sətir nömrəsi yazır
2. `flutter analyze` işlət — bütün səhvləri siyahılayır
3. Heç nə kömək etmirsə:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

---

## 4. main.dart-da nə var? (qısa xəritə)

| Bölmə | Nədir |
|---|---|
| `main()` | Tətbiq buradan başlayır |
| `LifeGrapherApp` | Tətbiqin çərçivəsi (rənglər, başlanğıc ekran) |
| `LifeStore` | BÜTÜN MƏLUMATLAR burada saxlanır (ad, yeməklər, yuxu, su) |
| `AuthScreen` | Giriş ekranı (ad + e-poçt) |
| `LifeShell` | Aşağıdakı naviqasiya çubuğu (4 tab) |
| `HomePage` | Ana səhifə |
| `NutritionPage` | Qidalanma səhifəsi |
| `SleepPage` | Yuxu səhifəsi |
| `ProfilePage` | Profil səhifəsi |

---

## 5. Vacib qaydalar

1. **`pubspec.yaml` dəyişəndən sonra həmişə `flutter pub get`**
2. **`build/` qovluğuna əl vurma** — Flutter özü idarə edir
3. Kodu dəyişəndə `r` ilə hot reload et — tətbiqi bağlamağa ehtiyac yoxdur
4. Böyük dəyişiklikdən əvvəl `flutter analyze` ilə yoxla
5. GitHub-a göndərməzdən əvvəl `flutter test` keçməlidir

---

## 6. Gələcək planlar (work qeydlərindən)

- [ ] Apple ilə giriş
- [ ] Google ilə giriş
- [ ] Instagram-a story kimi gözəl görünüş paylaşma
- [ ] Xəstəxana əlavə etmə funksiyası (Google xəritə ilə)
