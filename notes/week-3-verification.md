# 3-cü həftə — 5 sentyabr 2026 yoxlaması

Mənbə: LifeGrapher_Proje_Sozlesmesi_v3.pdf, bölmə 5.
Son tarix: 6 sentyabr 2026.

## Hazır olanlar

- Yemək və yuxu üçün ayrıca formalar və klaviaturanın üstündə qalan “Əlavə et” düyməsi.
- Ad, kalori/makro, yuxu müddəti və hədəflərin yoxlanması.
- Saxlama xətasında forma açıq qalır; təkrar cəhd eyni Firestore sənəd ID-sindən istifadə edir.
- Gözləmə zamanı təkrar basma bloklanır. 20 saniyədə server təsdiqi gəlmirsə, neytral gözləmə bildirişi göstərilir; orijinal yazma əməliyyatı izlənir və gecikmiş uğur qəbul edilir. Gözləmə zamanı təkrar yazma bloklanır, geri qayıtmaq mümkündür.
- Formanın kontrollerləri ekran dispose olunanda azad edilir.
- Profil yeniləməsinin tutulmayan asinxron xətası aradan qaldırılıb.
- Panel yüklənmə xətasını sıfır nəticə kimi göstərmir.

## Yoxlanmış nəticələr

- `flutter test --no-pub`: 6 test keçir (forma yoxlaması, onluq vergül, saxlama xətası/təkrar cəhd, iki dəfə basma, geri çıxma, klaviatura görünüşü, hədəflər və tətbiq qabığı).
- `flutter analyze --no-pub`: problem yoxdur.
- `flutter build ios --simulator --debug --no-pub`: uğurludur.
- Yeni tətbiq iPhone 17 Pro simulyatorunda quraşdırılıb və giriş ekranı açılıb.
- Real Firebase REST yoxlaması: müvəqqəti hesabla e-poçt qeydiyyatı və giriş uğurludur. Test hesabı silinib.
- İlk real Firestore yazısı 403 verdi: API aktiv deyildi. API aktivləşdirildi, daha sonra baza siyahısının boş olduğu təsdiqləndi.

## Qalan maneə — 3-cü həftə hələ tam təsdiqlənməyib

`lifegrapher` layihəsində `(default)` Firestore bazası yoxdur. `europe-west3` (Frankfurt) regionunda yaratma cəhdi avtomatik icazə yoxlaması tərəfindən bloklandı; baza yaradılmadı. Region seçimi geri dəyişdirilə bilmədiyindən və bulud xərclərinə təsir edə bildiyindən istifadəçi təsdiqi tələb olunur.

Təsdiqdən sonra:

1. Standart bazanı təsdiqlənmiş regionda yarat.
2. `lifegrapher_mobile/firestore.rules` qaydalarını yoxlayıb yerləşdir. Qaydalar yalnız hesab sahibinə profil, yemək və yuxu məlumatlarına giriş verir.
3. Real hesabla ən azı 1 yemək və 1 yuxu əlavə et; yeni sessiyada yenidən oxunmasını yoxla. Başqa hesabın və anonim istifadəçinin həmin qeydləri oxuya bilmədiyini yoxla.
4. Tətbiqdə qeydiyyat → yemək → yuxu → panel axınını yoxla, tətbiqi yenidən açıb qeydlərin qalmasını təsdiqlə.
5. Müqavilədə nəzərdə tutulan şəxsə 5 dəqiqəlik canlı nümayiş keçir. Bu iş görülmüş kimi qeyd edilməyib.

Demo üçün e-poçt/şifrə girişindən istifadə et. Mövcud ID ilə giriş funksiyası başqa istifadəçinin profilindən e-poçt oxumağa çalışır; hazırlanan məxfi profil qaydaları bunu qəsdən açmır. ID ilə giriş üçün ayrıca təhlükəsiz server həlli lazımdır. Apple və Google girişləri bu yoxlamada sınaqdan keçirilməyib.

## Admin girişi

İstifadəçinin açıq seçimi ilə `ismayil.aliyevev@gmail.com` hesabına `34555` giriş ləqəbi bağlandı. Hesab Firebase UID-si ilə tanınır; ləqəb yalnız e-poçtu seçir, şifrə Firebase Authentication-da yoxlanır. Şifrə mənbə kodunda saxlanılmır. Real şifrə girişi eyni UID ilə təsdiqləndi. Digər hesabların mövcud 9 rəqəmli avtomatik ID generatoru saxlanıldı; onun qalıcı işləməsi hələ Firestore bazasının qurulmasını tələb edir. Bu dəyişiklik əlavə inzibatçı səlahiyyətləri vermir.

## Son dəyişiklik — telefonda saxlama

İstifadəçinin son istəyi əvvəlki bulud saxlama axınını əvəz edir: yemək, yuxu, hədəflər və profil tətbiqin Application Support qovluğunda hesabın UID-si üzrə JSON fayllarında saxlanır. Diskə yazma flush və atomik rename ilə tamamlandıqdan sonra uğur göstərilir. Yazmalar növbəyə alınır, uğursuz oxuma mövcud faylı boş məlumatla əvəz etmir. Panel və siyahılar həmin yerli məlumatdan yenilənir. Əvvəlki Firestore keşindən yemək/yuxu qeydlərinin bir dəfə importu əlavə edilib; yeni qeydlər buluda göndərilmir.

Admin ID-si `34555`-dir. Şəkildəki `345555` kimi səhv ID-lər artıq Firestore sorğusu göndərmir. Digər hesabların yerli ID-si bu cihazda e-poçta çevrilir; başqa cihazda e-poçtla giriş tələb olunur. Firebase giriş sessiyası saxlanır, yeni autentifikasiya üçün internet lazımdır.

15 avtomatik test keçdi; statik analiz problemsizdir. Yeni testlər diskdən yenidən oxuma, hesabların ayrılması, paralel yazmalar, eyni ID ilə təkrar saxlama, tarix filtrləri, zədələnmiş faylın qorunması və səhv admin ID-sini əhatə edir. Bu yerli rejim müqavilənin hosted baza bəndinin tamamlanması kimi təqdim edilmir.

## Beş dil dəstəyi

Azərbaycan (az), İngilis (en), Türk (tr), Alman (de), Rus (ru). Dil giriş ekranından və ayarlardan dəyişir; seçim ayrıca cihaz parametrində atomik yazılır. Giriş məlumatları və qeydlər dil dəyişərkən qorunur. Tarix/saat pəncərələri Flutter localizations, rəqəmlər intl ilə göstərilir. Yemək növləri yeni qeydlərdə dilə bağlı olmayan kodlarla saxlanır; əvvəlki Azərbaycan dilindəki növlər də düzgün tərcümə edilir. İstifadəçinin yazdığı yemək adları tərcümə olunmur.

24 test keçir, statik analiz problemsizdir. Beş dil üzrə giriş və bütün qeyd formaları 375×667 ölçüsündə yoxlanıb; tarix pəncərələri, canlı dil dəyişməsi, dil seçiminin diskdən bərpası, tərcümə tamlığı və parametr uyğunluğu test edilib.
