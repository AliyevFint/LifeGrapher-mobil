# lifegrapher_mobile

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Bədən profili və çəki izləmə

İlk girişdə ad, yaş, boy, çəki, hədəf çəki, məqsəd və aktivlik forması açılır.
“İndi keç” cari sessiya üçün formanı keçir; “Bədənim” bölməsindən tamamlamaq mümkündür.
Təsdiqlənmiş profil təkrar girişdə yenidən soruşulmur. Profil və ilk çəki eyni atomik
JSON yazısında hesabın UID-si üzrə saxlanır.

“Bədənim” başlanğıc və son çəki görünüşünü, fərqi və tarixçəni göstərir.
Gündəlik/həftəlik/aylıq seçim növbəti qeyd tarixini göstərir; push bildiriş planlaşdırmır.
İstənilən vaxt tarix seçərək çəki əlavə etmək mümkündür. Keçmiş tarixli qeyd son çəkini
əvəz etmir. Sinə, qarın, bel, qol və ayaq tənzimləyiciləri vizual proporsiyalardır;
yağ faizi, tibbi ölçü və ya dərinin sallanması proqnozu deyil.

Yeni bölmənin mətnləri hazırda Azərbaycan dilindədir. Mövcud yerli saxlama rejimindən
istifadə edir; bulud sinxronlaşması əlavə edilməyib.
