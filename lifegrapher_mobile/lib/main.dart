import 'dart:async';

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'app_language.dart';
import 'firebase_options.dart';
import 'entry_page.dart';
import 'local_store.dart';
import 'body_profile.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await LocalStore.initialize();
  await appLanguage.initialize(LocalStore.instance.directory.parent);
  runApp(const LifeGrapherApp());
}

class LifeGrapherApp extends StatelessWidget {
  const LifeGrapherApp({super.key, this.home});

  /// Allows widget tests to render the app shell without Firebase services.
  final Widget? home;

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF1877C9);
    const leafGreen = Color(0xFF39A852);
    const pageBackground = Color(0xFFF5FAFF);
    return ValueListenableBuilder<Locale>(
      valueListenable: appLanguage,
      builder: (context, locale, _) => MaterialApp(
        locale: locale,
        supportedLocales: languageNames.keys
            .map((code) => Locale(code))
            .toList(),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        title: 'LifeGrapher',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: primaryBlue,
            brightness: Brightness.light,
          ).copyWith(secondary: leafGreen, surface: pageBackground),
          useMaterial3: true,
          scaffoldBackgroundColor: pageBackground,
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            prefixIconColor: primaryBlue,
            labelStyle: TextStyle(color: primaryBlue),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFFB9D7F2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFFB9D7F2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primaryBlue, width: 2),
            ),
          ),
        ),
        home: home ?? AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<User?> _subscription;
  User? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _subscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        // Keep the account profile on this device.
        unawaited(
          UserService.upsertUser(user).catchError((Object error) {
            debugPrint('Profil yenilənmədi: $error');
          }),
        );
      }
      if (mounted) {
        setState(() {
          _user = user;
          _loading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_user != null) {
      return BodyProfileGate(
        key: ValueKey(_user!.uid),
        uid: _user!.uid,
        child: const HomeScreen(),
      );
    }
    return LoginScreen();
  }
}

/// Maintains account-specific profiles on this device.
class UserService {
  static const adminUid = 'jJuNOAXRwZcsU3JXMsTRz8BnD4s1';
  static const adminLoginId = '34555';
  static const adminEmail = 'ismayil.aliyevev@gmail.com';

  /// Uses a separate, random numeric ID so people can sign in without typing
  /// their email address. The ID is never used as a Firebase password.
  static String _newLoginId() {
    final value = 100000000 + Random.secure().nextInt(900000000);
    return value.toString();
  }

  static Future<void> upsertUser(User user) async {
    final store = LocalStore.instance;
    final existing = await store.read(user.uid);
    final profile = Map<String, dynamic>.from(existing['profile'] as Map);
    String? loginId = profile['loginId'] as String?;
    if (user.uid == adminUid) {
      loginId = adminLoginId;
    } else if (loginId == null) {
      do {
        loginId = _newLoginId();
      } while (await store.emailForId(loginId) != null);
    }
    await store.saveProfile(user.uid, {
      'email': user.email,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
      'loginId': loginId,
    });
    unawaited(_importCachedRecords(user.uid));
  }

  static Future<void> _importCachedRecords(String uid) async {
    // Recover records queued by the earlier Firestore version without waiting
    // for the network. Existing local records always take precedence.
    try {
      final store = LocalStore.instance;
      final state = await store.read(uid);
      if ((state['profile'] as Map)['cacheImported'] == true) return;
      final ref = FirebaseFirestore.instance.collection('users').doc(uid);
      final cached = <String, Map<String, dynamic>>{};
      for (final name in ['meals', 'sleep']) {
        final result = await ref
            .collection(name)
            .get(GetOptions(source: Source.cache));
        cached[name] = {for (final doc in result.docs) doc.id: doc.data()};
      }
      await store.update(uid, (current) {
        for (final name in ['meals', 'sleep']) {
          current[name] = {
            ...cached[name]!,
            ...Map<String, dynamic>.from(current[name] as Map),
          };
        }
        (current['profile'] as Map)['cacheImported'] = true;
      });
    } catch (_) {
      // No previous cache is normal on a fresh installation.
    }
  }

  static Future<String?> findEmailForLoginId(String loginId) async {
    if (loginId.trim() == adminLoginId) return adminEmail;
    if (!RegExp(r'^\d{9}$').hasMatch(loginId.trim())) return null;
    return LocalStore.instance.emailForId(loginId.trim());
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegistering = false;
  bool _isBusy = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(Object error) {
    if (!mounted) return;
    final message = error is FirebaseAuthException
        ? switch (error.code) {
            'invalid-email' => tr(context, "Düzgün Gmail ünvanı yazın."),
            'email-already-in-use' => tr(
              context,
              "Bu Gmail artıq qeydiyyatdan keçib.",
            ),
            'weak-password' => tr(context, "Kod ən azı 6 simvol olmalıdır."),
            'invalid-credential' || 'wrong-password' => tr(
              context,
              "Gmail/ID nömrəsi və ya kod yanlışdır.",
            ),
            'network-request-failed' => tr(context, 'networkError'),
            'too-many-requests' => tr(context, 'tooManyRequests'),
            'user-disabled' => tr(context, 'accountDisabled'),
            _ => tr(context, "Giriş mümkün olmadı."),
          }
        : error is Exception && error.toString().startsWith('Exception: ')
        ? error.toString().replaceFirst('Exception: ', '')
        : tr(context, 'Giriş mümkün olmadı.');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _signInWithEmailOrId() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;
    if (identifier.isEmpty || password.isEmpty) {
      _showError(Exception(tr(context, "Gmail/ID nömrəsi və kodu yazın.")));
      return;
    }
    if (_isRegistering && !identifier.contains('@')) {
      _showError(Exception(tr(context, "Qeydiyyat üçün Gmail ünvanı yazın.")));
      return;
    }

    setState(() => _isBusy = true);
    try {
      if (_isRegistering) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: identifier,
          password: password,
        );
      } else {
        final email = identifier.contains('@')
            ? identifier
            : await UserService.findEmailForLoginId(identifier);
        if (!mounted) return;
        if (email == null) {
          throw Exception(
            tr(
              context,
              "Bu ID tapılmadı. Admin ID-si 34555-dir. Digər hesablar üçün e-poçtla daxil ola bilərsiniz.",
            ),
          );
        }
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _sendPasswordResetEmail() async {
    final controller = TextEditingController(
      text: _identifierController.text.trim(),
    );
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr(context, "Şifrəni yenilə")),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: InputDecoration(
            labelText: tr(context, "Gmail ünvanı"),
            hintText: 'ad@gmail.com',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(tr(context, "Ləğv et")),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(tr(context, "Linki göndər")),
          ),
        ],
      ),
    );
    // AlertDialog is removed with an animation; dispose after it unmounts.
    Future<void>.delayed(Duration(milliseconds: 350), controller.dispose);
    if (email == null || email.isEmpty) return;

    try {
      await FirebaseAuth.instance.setLanguageCode(
        appLanguage.value.languageCode,
      );
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(context, "Parol yeniləmə linki Gmail ünvanınıza göndərildi."),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (error) {
      _showError(error);
    }
  }

  Future<void> _signInWithApple(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final failureMessage = tr(context, "Giriş mümkün olmadı.");
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      await FirebaseAuth.instance.signInWithCredential(oauthCredential);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return;
      messenger.showSnackBar(
        SnackBar(content: Text(failureMessage), backgroundColor: Colors.red),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(failureMessage), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _signInWithGoogle(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final failureMessage = tr(context, "Giriş mümkün olmadı.");
    try {
      await GoogleSignIn.instance.initialize();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw StateError('Google kimlik belirteci alınamadı.');
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await FirebaseAuth.instance.signInWithCredential(credential);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(failureMessage), backgroundColor: Colors.red),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(failureMessage), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Sosial giriş düymələri ekranın aşağısında sabit qalır. Klaviatura
      // açılanda yalnız form hissəsi daralır və sürüşür.
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: LanguagePicker(compact: true),
                          ),
                          SizedBox(height: 12),
                          Center(
                            child: Image.asset(
                              'assets/logo.png',
                              width: 100,
                              height: 100,
                            ),
                          ),
                          SizedBox(height: 20),
                          Center(
                            child: Text(
                              'LifeGrapher',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF176AB2),
                              ),
                            ),
                          ),
                          SizedBox(height: 8),
                          Center(
                            child: Text(
                              tr(context, "Həyatını izləməyə başla"),
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF5E7285),
                              ),
                            ),
                          ),
                          SizedBox(height: 32),
                          TextField(
                            controller: _identifierController,
                            keyboardType: _isRegistering
                                ? TextInputType.emailAddress
                                : TextInputType.text,
                            decoration: InputDecoration(
                              labelText: tr(context, "Gmail və ya ID nömrəsi"),
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          SizedBox(height: 12),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            onSubmitted: (_) =>
                                _isBusy ? null : _signInWithEmailOrId(),
                            decoration: InputDecoration(
                              labelText: tr(context, "Kod"),
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                          ),
                          SizedBox(height: 16),
                          SizedBox(
                            height: 50,
                            child: FilledButton(
                              onPressed: _isBusy ? null : _signInWithEmailOrId,
                              child: _isBusy
                                  ? SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      _isRegistering
                                          ? tr(context, "Qeydiyyatdan keç")
                                          : tr(context, "Daxil ol"),
                                    ),
                            ),
                          ),
                          TextButton(
                            onPressed: _isBusy
                                ? null
                                : () => setState(
                                    () => _isRegistering = !_isRegistering,
                                  ),
                            child: Text(
                              _isRegistering
                                  ? tr(context, "Hesabın var? Daxil ol")
                                  : tr(context, "Yeni hesab yarat"),
                            ),
                          ),
                          TextButton(
                            onPressed: _isBusy ? null : _sendPasswordResetEmail,
                            child: Text(
                              tr(context, "Şifrəni unutdun? Gmail ilə yenilə"),
                            ),
                          ),
                          SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(tr(context, "və ya")),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: SignInWithAppleButton(
                      text: tr(context, "Apple ilə daxil ol"),
                      onPressed: () => _signInWithApple(context),
                      style: SignInWithAppleButtonStyle.black,
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () => _signInWithGoogle(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.black26),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'G',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4285F4),
                            ),
                          ),
                          SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              tr(context, "Google ilə daxil ol"),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('LifeGrapher')),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const DashboardPage(),
          const AddPage(),
          BodyProgressPage(uid: FirebaseAuth.instance.currentUser!.uid),
          const SettingsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: tr(context, "Panel"),
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: tr(context, "Əlavə et"),
          ),
          NavigationDestination(
            icon: Icon(Icons.accessibility_new),
            label: 'Bədənim',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: tr(context, "Ayarlar"),
          ),
        ],
      ),
    );
  }
}

LocalCollection _userCollection(String name) => LocalStore.instance.collection(
  FirebaseAuth.instance.currentUser!.uid,
  name,
);

DateTime _startOfDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _timeText(BuildContext context, DateTime value) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(value),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _signOut(BuildContext context) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr(context, "Hesabdan çıxış")),
        content: Text(tr(context, "Hesabdan çıxmaq istədiyinə əminsən?")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr(context, "Ləğv et")),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr(context, "Çıxış et")),
          ),
        ],
      ),
    );
    if (shouldSignOut == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  Future<void> _editGoals(
    BuildContext context,
    Map<String, dynamic>? profile,
  ) => _showEntryPage(context, EntryKind.goals, profile: profile);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return SizedBox.shrink();
    return StreamBuilder<LocalProfileSnapshot>(
      stream: LocalStore.instance.profile(user.uid),
      builder: (context, snapshot) {
        final profile = snapshot.data?.data();
        final loginId = user.uid == UserService.adminUid
            ? UserService.adminLoginId
            : profile?['loginId'] as String?;
        return ListView(
          padding: EdgeInsets.all(20),
          children: [
            Text(
              tr(context, "Ayarlar"),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 20),
            _SettingsHeading(tr(context, "Hesab")),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.person_outline),
                    title: Text(
                      user.displayName?.isNotEmpty == true
                          ? user.displayName!
                          : tr(context, "LifeGrapher istifadəçisi"),
                    ),
                    subtitle: Text(
                      user.email ?? tr(context, "E-poçt məlumatı yoxdur"),
                    ),
                  ),
                  Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.pin_outlined),
                    title: Text(tr(context, "Giriş ID nömrəsi")),
                    trailing: Text(loginId ?? tr(context, "Yüklənir")),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            _SettingsHeading(tr(context, "Gündəlik hədəflər")),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.local_fire_department_outlined),
                    title: Text(tr(context, "Kalori hədəfi")),
                    trailing: Text(
                      amount(
                        context,
                        'kcalValue',
                        (profile?['calorieGoal'] as num?) ?? 2000,
                      ),
                    ),
                  ),
                  Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.bedtime_outlined),
                    title: Text(tr(context, "Yuxu hədəfi")),
                    trailing: Text(
                      amount(
                        context,
                        'hoursValue',
                        ((profile?['sleepGoalMinutes'] as num?) ?? 480) / 60,
                        1,
                      ),
                    ),
                  ),
                  Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text(tr(context, "Hədəfləri dəyiş")),
                    trailing: Icon(Icons.chevron_right),
                    onTap: () => _editGoals(context, profile),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            _SettingsHeading(tr(context, "Tətbiq")),
            Card(
              child: Column(
                children: [
                  LanguagePicker(),
                  Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.cloud_done_outlined),
                    title: Text(tr(context, "Məlumatların saxlanması")),
                    subtitle: Text(
                      tr(
                        context,
                        "Qeydləriniz təhlükəsiz şəkildə hesabınıza bağlı saxlanır",
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => _signOut(context),
              icon: Icon(Icons.logout, color: Colors.red),
              label: Text(
                tr(context, "Hesabdan çıxış et"),
                style: TextStyle(color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SettingsHeading extends StatelessWidget {
  const _SettingsHeading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(left: 4, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

enum DashboardRange { daily, weekly, monthly, yearly }

class _DashboardPageState extends State<DashboardPage> {
  DashboardRange _range = DashboardRange.daily;

  @override
  Widget build(BuildContext context) {
    final today = _startOfDay(DateTime.now());
    final start = switch (_range) {
      DashboardRange.daily => today,
      DashboardRange.weekly => today.subtract(
        Duration(days: today.weekday - DateTime.monday),
      ),
      DashboardRange.monthly => DateTime(today.year, today.month),
      DashboardRange.yearly => DateTime(today.year),
    };
    final end = switch (_range) {
      DashboardRange.daily => start.add(Duration(days: 1)),
      DashboardRange.weekly => start.add(Duration(days: 7)),
      DashboardRange.monthly => DateTime(start.year, start.month + 1),
      DashboardRange.yearly => DateTime(start.year + 1),
    };
    final period = switch (_range) {
      DashboardRange.daily => tr(context, "Bugünün xülasəsi"),
      DashboardRange.weekly => tr(context, "Bu həftənin xülasəsi"),
      DashboardRange.monthly => tr(context, "Bu ayın xülasəsi"),
      DashboardRange.yearly => tr(context, "Bu ilin xülasəsi"),
    };
    return StreamBuilder<LocalSnapshot>(
      stream: _userCollection('meals')
          .where('loggedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('loggedAt', isLessThan: Timestamp.fromDate(end))
          .snapshots(),
      builder: (context, mealsSnapshot) {
        if (mealsSnapshot.hasError) {
          return Center(
            child: Text(
              tr(
                context,
                "Yemək məlumatları yüklənmədi. Tətbiqi yenidən açın.",
              ),
            ),
          );
        }
        if (!mealsSnapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }
        final meals =
            mealsSnapshot.data?.docs.map((doc) => doc.data()).toList() ?? [];
        num sum(String key) => meals.fold<num>(
          0,
          (total, meal) => total + ((meal[key] as num?) ?? 0),
        );
        final calories = sum('calories');
        final protein = sum('protein');
        final carbs = sum('carbs');
        final fat = sum('fat');
        return StreamBuilder<LocalSnapshot>(
          stream: _userCollection('sleep')
              .where(
                'wakeTime',
                isGreaterThanOrEqualTo: Timestamp.fromDate(start),
              )
              .where('wakeTime', isLessThan: Timestamp.fromDate(end))
              .snapshots(),
          builder: (context, sleepSnapshot) {
            if (sleepSnapshot.hasError) {
              return Center(
                child: Text(
                  tr(
                    context,
                    "Yuxu məlumatları yüklənmədi. Tətbiqi yenidən açın.",
                  ),
                ),
              );
            }
            if (!sleepSnapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            }
            final sleep =
                sleepSnapshot.data?.docs.map((doc) => doc.data()).toList() ??
                [];
            final sleepMinutes = sleep.fold<int>(
              0,
              (total, item) =>
                  total + ((item['durationMinutes'] as num?)?.toInt() ?? 0),
            );
            final user = FirebaseAuth.instance.currentUser!;
            return StreamBuilder<LocalProfileSnapshot>(
              stream: LocalStore.instance.profile(user.uid),
              builder: (context, profileSnapshot) {
                final profile = profileSnapshot.data?.data();
                final calorieGoal =
                    (profile?['calorieGoal'] as num?)?.toDouble() ?? 2000;
                final sleepGoalMinutes =
                    (profile?['sleepGoalMinutes'] as num?)?.toInt() ?? 480;
                final goalMultiplier = end.difference(start).inDays;
                final calorieTarget = calorieGoal * goalMultiplier;
                final sleepTarget = sleepGoalMinutes * goalMultiplier;
                return StreamBuilder<LocalSnapshot>(
                  stream: _userCollection('water')
                      .where(
                        'loggedAt',
                        isGreaterThanOrEqualTo: Timestamp.fromDate(start),
                      )
                      .where('loggedAt', isLessThan: Timestamp.fromDate(end))
                      .snapshots(),
                  builder: (context, waterSnapshot) {
                    final water =
                        waterSnapshot.data?.docs
                            .map((doc) => doc.data())
                            .toList() ??
                        [];
                    final waterMl = water.fold<num>(
                      0,
                      (total, item) =>
                          total + ((item['milliliters'] as num?) ?? 0),
                    );
                    final waterTarget = 2500 * goalMultiplier;
                    return ListView(
                      padding: EdgeInsets.all(20),
                      children: [
                        Text(
                          period,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        SizedBox(height: 4),
                        Text(
                          tr(
                            context,
                            "Yemək və yuxu qeydlərin burada toplanır.",
                          ),
                        ),
                        SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _rangeChip(
                              tr(context, "Günlük"),
                              DashboardRange.daily,
                            ),
                            _rangeChip(
                              tr(context, "Həftəlik"),
                              DashboardRange.weekly,
                            ),
                            _rangeChip(
                              tr(context, "Aylıq"),
                              DashboardRange.monthly,
                            ),
                            _rangeChip(
                              tr(context, "İllik"),
                              DashboardRange.yearly,
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        _GoalSummaryCard(
                          icon: Icons.local_fire_department_outlined,
                          title: tr(context, "Kalori"),
                          value: amount(context, 'kcalValue', calories),
                          target: amount(
                            context,
                            'calorieTarget',
                            calorieTarget,
                          ),
                          progress: calorieTarget == 0
                              ? 0
                              : calories / calorieTarget,
                          subtitle: amount(context, 'mealCount', meals.length),
                          onTap: () => showDialog<void>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: Text(tr(context, 'Kalori məlumatı')),
                              content: Text(
                                tr(
                                  context,
                                  'Kalori yediyiniz bütün yeməklərin cəmidir. Bu kart gün və ya seçdiyiniz dövr üçün ümumi kalorini, hədəfi və irəliləyişi göstərir.',
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: Text(tr(context, 'Ləğv et')),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr(context, "Makrolar"),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 17,
                                  ),
                                ),
                                SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _Macro(
                                        label: tr(context, "Protein"),
                                        value: amount(
                                          context,
                                          'gramValue',
                                          protein,
                                        ),
                                        color: Colors.red,
                                      ),
                                    ),
                                    Expanded(
                                      child: _Macro(
                                        label: tr(context, "Karbohidrat"),
                                        value: amount(
                                          context,
                                          'gramValue',
                                          carbs,
                                        ),
                                        color: Colors.orange,
                                      ),
                                    ),
                                    Expanded(
                                      child: _Macro(
                                        label: tr(context, "Yağ"),
                                        value: amount(
                                          context,
                                          'gramValue',
                                          fat,
                                        ),
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 12),
                        _GoalSummaryCard(
                          icon: Icons.bedtime_outlined,
                          title: tr(context, "Yuxu"),
                          value: amount(
                            context,
                            'hoursValue',
                            sleepMinutes / 60,
                            1,
                          ),
                          target: amount(
                            context,
                            'sleepTarget',
                            sleepTarget / 60,
                            1,
                          ),
                          progress: sleepTarget == 0
                              ? 0
                              : sleepMinutes / sleepTarget,
                          subtitle: amount(context, 'sleepCount', sleep.length),
                        ),
                        SizedBox(height: 12),
                        _GoalSummaryCard(
                          icon: Icons.water_drop_outlined,
                          title: tr(context, 'Gündəlik su'),
                          value: amount(context, 'mlValue', waterMl),
                          target: amount(context, 'waterTarget', waterTarget),
                          progress: waterTarget == 0
                              ? 0
                              : waterMl / waterTarget,
                          subtitle: amount(context, 'suCount', water.length),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _rangeChip(String label, DashboardRange value) => ChoiceChip(
    label: Text(label),
    selected: _range == value,
    onSelected: (_) => setState(() => _range = value),
  );
}

class _GoalSummaryCard extends StatelessWidget {
  const _GoalSummaryCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.target,
    required this.progress,
    required this.subtitle,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String value;
  final String target;
  final num progress;
  final String subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 30,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      Text(subtitle),
                    ],
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ],
            ),
            SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress.clamp(0, 1).toDouble(),
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
            SizedBox(height: 7),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(target, style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Macro extends StatelessWidget {
  const _Macro({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 17,
        ),
      ),
      SizedBox(height: 4),
      Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
    ],
  );
}

class AddPage extends StatefulWidget {
  const AddPage({super.key});

  @override
  State<AddPage> createState() => _AddPageState();
}

class _AddPageState extends State<AddPage> {
  EntryKind _selected = EntryKind.meal;
  bool _addingGlass = false;

  String get _collection => switch (_selected) {
    EntryKind.meal => 'meals',
    EntryKind.sleep => 'sleep',
    EntryKind.water => 'water',
    EntryKind.goals => 'profile',
  };

  Future<bool> _confirmDelete() async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(tr(context, 'Qeydi sil')),
          content: Text(tr(context, 'Bu qeydi silmək istəyirsiniz?')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(tr(context, 'Ləğv et')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(tr(context, 'Sil')),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _addGlass() async {
    if (_addingGlass) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _addingGlass = true);
    try {
      await LocalStore.instance.saveEntry(
        user.uid,
        'water',
        LocalStore.instance.newId(),
        {
          'milliliters': 250,
          'loggedAt': DateTime.now(),
          'createdAt': DateTime.now(),
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tr(context, 'Uğurla əlavə edildi! 🎉')} 250 ml'),
        ),
      );
    } finally {
      if (mounted) setState(() => _addingGlass = false);
    }
  }

  Widget _typeButton(EntryKind kind, IconData icon, String label) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: FilledButton.tonalIcon(
        onPressed: () {
          setState(() => _selected = kind);
          if (kind != EntryKind.water) _showEntryPage(context, kind);
        },
        icon: Icon(icon),
        label: Text(label, overflow: TextOverflow.ellipsis),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final labels = <EntryKind, String>{
      EntryKind.meal: tr(context, 'Yeməklər'),
      EntryKind.sleep: tr(context, 'Yuxu'),
      EntryKind.water: tr(context, 'Su'),
    };
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
          child: Row(
            children: [
              _typeButton(
                EntryKind.meal,
                Icons.restaurant,
                labels[EntryKind.meal]!,
              ),
              _typeButton(
                EntryKind.sleep,
                Icons.bedtime,
                labels[EntryKind.sleep]!,
              ),
              _typeButton(
                EntryKind.water,
                Icons.water_drop,
                labels[EntryKind.water]!,
              ),
            ],
          ),
        ),
        if (_selected == EntryKind.water)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _addingGlass ? null : _addGlass,
                    icon: const Icon(Icons.local_drink),
                    label: Text('${tr(context, 'Bir stəkan')} (250 ml)'),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _showEntryPage(context, EntryKind.water),
                  child: Text(tr(context, 'Fərqli miqdar')),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SegmentedButton<EntryKind>(
            showSelectedIcon: false,
            segments: [
              for (final entry in labels.entries)
                ButtonSegment(value: entry.key, label: Text(entry.value)),
            ],
            selected: {_selected},
            onSelectionChanged: (value) =>
                setState(() => _selected = value.single),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<LocalSnapshot>(
            stream: _userCollection(_collection)
                .orderBy(
                  _selected == EntryKind.sleep ? 'wakeTime' : 'loggedAt',
                  descending: true,
                )
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final entries = snapshot.data!.docs;
              if (entries.isEmpty) {
                return _EmptyState(
                  icon: _selected == EntryKind.meal
                      ? Icons.restaurant_outlined
                      : _selected == EntryKind.sleep
                      ? Icons.bedtime_outlined
                      : Icons.water_drop_outlined,
                  title: _selected == EntryKind.meal
                      ? tr(context, 'Hələ yemək qeydi yoxdur')
                      : _selected == EntryKind.sleep
                      ? tr(context, 'Hələ yuxu qeydi yoxdur')
                      : tr(context, 'Su qeydləri'),
                  message: _selected == EntryKind.meal
                      ? tr(context, 'İlk yeməyini əlavə et.')
                      : _selected == EntryKind.sleep
                      ? tr(context, 'Yuxu saatlarını əlavə et.')
                      : tr(context, 'Gündə içdiyiniz su miqdarını yazın.'),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final data = entry.data();
                  return Dismissible(
                    key: ValueKey('$_collection-${entry.id}'),
                    direction: DismissDirection.horizontal,
                    background: Container(
                      color: Colors.blue,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 24),
                      child: const Icon(Icons.edit, color: Colors.white),
                    ),
                    secondaryBackground: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (direction) async {
                      final collection = _collection;
                      final uid = FirebaseAuth.instance.currentUser!.uid;
                      final messenger = ScaffoldMessenger.of(context);
                      final deletedMessage = tr(context, 'Qeyd silindi.');
                      if (direction == DismissDirection.startToEnd) {
                        await _showEntryPage(
                          context,
                          _selected,
                          initialData: data,
                          entryId: entry.id,
                        );
                        return false;
                      }
                      if (!await _confirmDelete()) {
                        return false;
                      }
                      await LocalStore.instance.deleteEntry(
                        uid,
                        collection,
                        entry.id,
                      );
                      if (!mounted) return false;
                      messenger.showSnackBar(
                        SnackBar(content: Text(deletedMessage)),
                      );
                      return true;
                    },
                    child: Card(child: _entryTile(context, data)),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _entryTile(BuildContext context, Map<String, dynamic> data) {
    if (_selected == EntryKind.meal) {
      final time = (data['loggedAt'] as Timestamp?)?.toDate();
      return ListTile(
        leading: const Icon(Icons.restaurant),
        title: Text(data['name'] as String? ?? tr(context, 'Yemək')),
        subtitle: Text(
          '${mealTypeText(context, data['mealType'] as String?)}${time == null ? '' : ' • ${_timeText(context, time)}'}\n${tr(context, 'macroValues', {
            for (final key in ['protein', 'carbs', 'fat']) key: formatNumber(context, (data[key] as num?) ?? 0, 1),
          })}',
        ),
        isThreeLine: true,
        trailing: Text(
          amount(context, 'kcalValue', (data['calories'] as num?) ?? 0),
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
    }
    if (_selected == EntryKind.sleep) {
      final bed = (data['bedtime'] as Timestamp).toDate();
      final wake = (data['wakeTime'] as Timestamp).toDate();
      final minutes = (data['durationMinutes'] as num).toInt();
      return ListTile(
        leading: const Icon(Icons.bedtime),
        title: Text('${_timeText(context, bed)} – ${_timeText(context, wake)}'),
        subtitle: Text(
          amount(context, 'qualityValue', (data['quality'] as num?) ?? 3),
        ),
        trailing: Text(
          amount(context, 'hoursValue', minutes / 60, 1),
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
    }
    return ListTile(
      leading: const Icon(Icons.water_drop),
      title: Text(
        amount(context, 'mlValue', (data['milliliters'] as num?) ?? 0),
      ),
      subtitle: Text(tr(context, 'Gündəlik su')),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

Future<void> _showEntryPage(
  BuildContext context,
  EntryKind kind, {
  Map<String, dynamic>? profile,
  Map<String, dynamic>? initialData,
  String? entryId,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  final store = LocalStore.instance;
  final id = entryId ?? store.newId();
  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => EntryPage(
        kind: kind,
        profile: profile,
        initialData: initialData,
        onSave: (data) async {
          if (FirebaseAuth.instance.currentUser?.uid != user.uid) {
            throw StateError(tr(context, "Hesab sessiyası dəyişib."));
          }
          if (kind == EntryKind.goals) {
            await store.saveProfile(user.uid, data);
          } else {
            await store.saveEntry(
              user.uid,
              switch (kind) {
                EntryKind.meal => 'meals',
                EntryKind.sleep => 'sleep',
                EntryKind.water => 'water',
                EntryKind.goals => 'profile',
              },
              id,
              {
                ...initialData ?? <String, dynamic>{},
                ...data,
                'createdAt': initialData?['createdAt'] ?? DateTime.now(),
              },
            );
          }
        },
      ),
    ),
  );
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF237A45),
        duration: Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                kind == EntryKind.goals
                    ? tr(context, "Hədəflər uğurla saxlanıldı! 🎉")
                    : tr(context, "Uğurla əlavə edildi! 🎉"),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
