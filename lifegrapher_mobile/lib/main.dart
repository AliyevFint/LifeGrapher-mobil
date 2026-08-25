import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const LifeGrapherApp());
}

class LifeGrapherApp extends StatelessWidget {
  const LifeGrapherApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF1877C9);
    const leafGreen = Color(0xFF39A852);
    const pageBackground = Color(0xFFF5FAFF);
    return MaterialApp(
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
          labelStyle: const TextStyle(color: primaryBlue),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFB9D7F2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFB9D7F2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryBlue, width: 2),
          ),
        ),
      ),
      home: const AuthGate(),
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
        // Kullanıcıyı Firestore'a kaydet / güncelle.
        UserService.upsertUser(user);
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_user != null) {
      return const HomeScreen();
    }
    return const LoginScreen();
  }
}

/// Firestore'da `users/{uid}` dokümanını oluşturur veya günceller.
class UserService {
  /// Uses a separate, random numeric ID so people can sign in without typing
  /// their email address. The ID is never used as a Firebase password.
  static String _newLoginId() {
    final value = 100000000 + Random.secure().nextInt(900000000);
    return value.toString();
  }

  static Future<void> upsertUser(User user) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final data = <String, dynamic>{
      'email': user.email,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
      'providers': user.providerData.map((p) => p.providerId).toList(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    };
    final snapshot = await ref.get();
    // Keep the original ID forever. Profiles created before this feature have
    // no loginId yet, so they receive one exactly once below.
    if (snapshot.data()?['loginId'] is String) {
      await ref.set(data, SetOptions(merge: true));
      return;
    }

    // `userIds/{loginId}` reserves the value, avoiding an accidental ID
    // collision even when two users sign up at the same time.
    for (var attempt = 0; attempt < 10; attempt++) {
      final loginId = _newLoginId();
      final idRef = FirebaseFirestore.instance
          .collection('userIds')
          .doc(loginId);
      final created = await FirebaseFirestore.instance.runTransaction((
        tx,
      ) async {
        final existingUser = await tx.get(ref);
        if (existingUser.data()?['loginId'] is String) {
          tx.set(ref, data, SetOptions(merge: true));
          return true;
        }
        final existingId = await tx.get(idRef);
        if (existingId.exists) return false;

        tx.set(idRef, {
          'uid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.set(ref, {
          ...data,
          'loginId': loginId,
          if (!existingUser.exists) 'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: existingUser.exists));
        return true;
      });
      if (created) return;
    }

    throw StateError('Unikal giriş nömrəsi yaradıla bilmədi.');
  }

  static Future<String?> findEmailForLoginId(String loginId) async {
    final idSnapshot = await FirebaseFirestore.instance
        .collection('userIds')
        .doc(loginId)
        .get();
    final uid = idSnapshot.data()?['uid'] as String?;
    if (uid == null) return null;
    final userSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return userSnapshot.data()?['email'] as String?;
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
            'invalid-email' => 'Düzgün Gmail ünvanı yazın.',
            'email-already-in-use' => 'Bu Gmail artıq qeydiyyatdan keçib.',
            'weak-password' => 'Kod ən azı 6 simvol olmalıdır.',
            'invalid-credential' ||
            'wrong-password' => 'Gmail/ID nömrəsi və ya kod yanlışdır.',
            _ => error.message ?? 'Giriş mümkün olmadı.',
          }
        : error.toString().replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _signInWithEmailOrId() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;
    if (identifier.isEmpty || password.isEmpty) {
      _showError(Exception('Gmail/ID nömrəsi və kodu yazın.'));
      return;
    }
    if (_isRegistering && !identifier.contains('@')) {
      _showError(Exception('Qeydiyyat üçün Gmail ünvanı yazın.'));
      return;
    }

    setState(() => _isBusy = true);
    try {
      if (_isRegistering) {
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: identifier,
              password: password,
            );
        await UserService.upsertUser(credential.user!);
      } else {
        final email = identifier.contains('@')
            ? identifier
            : await UserService.findEmailForLoginId(identifier);
        if (email == null) {
          throw Exception('Bu ID nömrəsi ilə hesab tapılmadı.');
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
        title: const Text('Şifrəni yenilə'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Gmail ünvanı',
            hintText: 'ad@gmail.com',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Ləğv et'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Linki göndər'),
          ),
        ],
      ),
    );
    // AlertDialog is removed with an animation; dispose after it unmounts.
    Future<void>.delayed(const Duration(milliseconds: 350), controller.dispose);
    if (email == null || email.isEmpty) return;

    try {
      await FirebaseAuth.instance.setLanguageCode('az');
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Parol yeniləmə linki Gmail ünvanınıza göndərildi.'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (error) {
      _showError(error);
    }
  }

  Future<void> _signInWithApple(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
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
        SnackBar(
          content: Text('Apple girişi başarısız: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Giriş hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _signInWithGoogle(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
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
        SnackBar(
          content: Text('Google girişi başarısız: ${e.description ?? e.code}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Giriş hatası: $e'),
          backgroundColor: Colors.red,
        ),
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
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 36),
                          Center(
                            child: Image.asset(
                              'assets/logo.png',
                              width: 100,
                              height: 100,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Center(
                            child: Text(
                              'LifeGrapher',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF176AB2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Center(
                            child: Text(
                              'Həyatını izləməyə başla',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF5E7285),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          TextField(
                            controller: _identifierController,
                            keyboardType: _isRegistering
                                ? TextInputType.emailAddress
                                : TextInputType.text,
                            decoration: const InputDecoration(
                              labelText: 'Gmail və ya ID nömrəsi',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            onSubmitted: (_) =>
                                _isBusy ? null : _signInWithEmailOrId(),
                            decoration: const InputDecoration(
                              labelText: 'Kod',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 50,
                            child: FilledButton(
                              onPressed: _isBusy ? null : _signInWithEmailOrId,
                              child: _isBusy
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      _isRegistering
                                          ? 'Qeydiyyatdan keç'
                                          : 'Daxil ol',
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
                                  ? 'Hesabın var? Daxil ol'
                                  : 'Yeni hesab yarat',
                            ),
                          ),
                          TextButton(
                            onPressed: _isBusy ? null : _sendPasswordResetEmail,
                            child: const Text(
                              'Şifrəni unutdun? Gmail ilə yenilə',
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('və ya'),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: SignInWithAppleButton(
                      onPressed: () => _signInWithApple(context),
                      style: SignInWithAppleButtonStyle.black,
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () => _signInWithGoogle(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.black26),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Row(
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
                          Text(
                            'Google ilə daxil ol',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
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
      appBar: AppBar(
        title: const Text('LifeGrapher'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [DashboardPage(), MealsPage(), SleepPage()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Panel',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_outlined),
            selectedIcon: Icon(Icons.restaurant),
            label: 'Yeməklər',
          ),
          NavigationDestination(
            icon: Icon(Icons.bedtime_outlined),
            selectedIcon: Icon(Icons.bedtime),
            label: 'Yuxu',
          ),
        ],
      ),
    );
  }
}

CollectionReference<Map<String, dynamic>> _userCollection(String name) {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection(name);
}

DateTime _startOfDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _twoDigits(int value) => value.toString().padLeft(2, '0');
String _timeText(DateTime value) =>
    '${_twoDigits(value.hour)}:${_twoDigits(value.minute)}';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final today = _startOfDay(DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _userCollection('meals')
          .where('loggedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
          .where('loggedAt', isLessThan: Timestamp.fromDate(tomorrow))
          .snapshots(),
      builder: (context, mealsSnapshot) {
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
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _userCollection('sleep')
              .where(
                'wakeTime',
                isGreaterThanOrEqualTo: Timestamp.fromDate(today),
              )
              .where('wakeTime', isLessThan: Timestamp.fromDate(tomorrow))
              .snapshots(),
          builder: (context, sleepSnapshot) {
            final sleep =
                sleepSnapshot.data?.docs.map((doc) => doc.data()).toList() ??
                [];
            final sleepMinutes = sleep.fold<int>(
              0,
              (total, item) =>
                  total + ((item['durationMinutes'] as num?)?.toInt() ?? 0),
            );
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Bugünün xülasəsi',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                const Text('Yemək və yuxu qeydlərin burada toplanır.'),
                const SizedBox(height: 20),
                _SummaryCard(
                  icon: Icons.local_fire_department_outlined,
                  title: 'Kalori',
                  value: '${calories.toStringAsFixed(0)} kcal',
                  subtitle: '${meals.length} yemək qeydi',
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Makrolar',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _Macro(
                                label: 'Protein',
                                value: '${protein.toStringAsFixed(0)} g',
                                color: Colors.red,
                              ),
                            ),
                            Expanded(
                              child: _Macro(
                                label: 'Karbohidrat',
                                value: '${carbs.toStringAsFixed(0)} g',
                                color: Colors.orange,
                              ),
                            ),
                            Expanded(
                              child: _Macro(
                                label: 'Yağ',
                                value: '${fat.toStringAsFixed(0)} g',
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _SummaryCard(
                  icon: Icons.bedtime_outlined,
                  title: 'Yuxu',
                  value: '${(sleepMinutes / 60).toStringAsFixed(1)} saat',
                  subtitle: '${sleep.length} yuxu qeydi',
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(
        icon,
        size: 32,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
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
      const SizedBox(height: 4),
      Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12),
      ),
    ],
  );
}

class MealsPage extends StatelessWidget {
  const MealsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _userCollection('meals')
            .orderBy('loggedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Yemək qeydləri yüklənmədi.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final meals = snapshot.data!.docs;
          if (meals.isEmpty) {
            return const _EmptyState(
              icon: Icons.restaurant_outlined,
              title: 'Hələ yemək qeydi yoxdur',
              message: 'İlk yeməyini əlavə et.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: meals.length,
            itemBuilder: (context, index) {
              final data = meals[index].data();
              final time = (data['loggedAt'] as Timestamp?)?.toDate();
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.restaurant),
                  title: Text(data['name'] as String? ?? 'Yemək'),
                  subtitle: Text(
                    '${data['mealType'] ?? 'Yemək'}${time == null ? '' : ' • ${_timeText(time)}'}\nP: ${data['protein'] ?? 0}g  K: ${data['carbs'] ?? 0}g  Y: ${data['fat'] ?? 0}g',
                  ),
                  isThreeLine: true,
                  trailing: Text(
                    '${data['calories'] ?? 0}\nkcal',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showMealDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Yemək əlavə et'),
      ),
    );
  }
}

class SleepPage extends StatelessWidget {
  const SleepPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _userCollection('sleep')
            .orderBy('wakeTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Yuxu qeydləri yüklənmədi.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data!.docs;
          if (entries.isEmpty) {
            return const _EmptyState(
              icon: Icons.bedtime_outlined,
              title: 'Hələ yuxu qeydi yoxdur',
              message: 'Yuxu saatlarını əlavə et.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final data = entries[index].data();
              final bed = (data['bedtime'] as Timestamp).toDate();
              final wake = (data['wakeTime'] as Timestamp).toDate();
              final minutes = (data['durationMinutes'] as num).toInt();
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.bedtime),
                  title: Text('${_timeText(bed)} – ${_timeText(wake)}'),
                  subtitle: Text('Keyfiyyət: ${data['quality']}/5'),
                  trailing: Text(
                    '${(minutes / 60).toStringAsFixed(1)}\nsaat',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSleepDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Yuxu əlavə et'),
      ),
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
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

Future<void> _showMealDialog(BuildContext context) async {
  final name = TextEditingController();
  final calories = TextEditingController();
  final protein = TextEditingController(text: '0');
  final carbs = TextEditingController(text: '0');
  final fat = TextEditingController(text: '0');
  String mealType = 'Səhər yeməyi';
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Yemək əlavə et'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Yeməyin adı'),
              ),
              DropdownButtonFormField<String>(
                initialValue: mealType,
                decoration: const InputDecoration(labelText: 'Növ'),
                items:
                    const ['Səhər yeməyi', 'Nahar', 'Şam yeməyi', 'Ara yemək']
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setDialogState(() => mealType = value!),
              ),
              TextField(
                controller: calories,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Kalori (kcal)'),
              ),
              TextField(
                controller: protein,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Protein (g)'),
              ),
              TextField(
                controller: carbs,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Karbohidrat (g)'),
              ),
              TextField(
                controller: fat,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Yağ (g)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Ləğv et'),
          ),
          FilledButton(
            onPressed: () async {
              final calorieValue = double.tryParse(
                calories.text.replaceAll(',', '.'),
              );
              if (name.text.trim().isEmpty || calorieValue == null) return;
              await _userCollection('meals').add({
                'name': name.text.trim(),
                'mealType': mealType,
                'calories': calorieValue,
                'protein':
                    double.tryParse(protein.text.replaceAll(',', '.')) ?? 0,
                'carbs': double.tryParse(carbs.text.replaceAll(',', '.')) ?? 0,
                'fat': double.tryParse(fat.text.replaceAll(',', '.')) ?? 0,
                'loggedAt': Timestamp.now(),
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Yadda saxla'),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  calories.dispose();
  protein.dispose();
  carbs.dispose();
  fat.dispose();
}

Future<void> _showSleepDialog(BuildContext context) async {
  DateTime bedtime = DateTime.now().subtract(const Duration(hours: 8));
  DateTime wakeTime = DateTime.now();
  int quality = 3;
  Future<DateTime?> pick(DateTime current) async {
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    return time == null
        ? null
        : DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Yuxu əlavə et'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Yatış saatı'),
              subtitle: Text(
                '${bedtime.day}.${bedtime.month}.${bedtime.year} • ${_timeText(bedtime)}',
              ),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                final value = await pick(bedtime);
                if (value != null) setDialogState(() => bedtime = value);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Oyanış saatı'),
              subtitle: Text(
                '${wakeTime.day}.${wakeTime.month}.${wakeTime.year} • ${_timeText(wakeTime)}',
              ),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                final value = await pick(wakeTime);
                if (value != null) setDialogState(() => wakeTime = value);
              },
            ),
            DropdownButtonFormField<int>(
              initialValue: quality,
              decoration: const InputDecoration(labelText: 'Yuxu keyfiyyəti'),
              items: List.generate(
                5,
                (index) => DropdownMenuItem(
                  value: index + 1,
                  child: Text('${index + 1} / 5'),
                ),
              ),
              onChanged: (value) => setDialogState(() => quality = value!),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Ləğv et'),
          ),
          FilledButton(
            onPressed: wakeTime.isAfter(bedtime)
                ? () async {
                    await _userCollection('sleep').add({
                      'bedtime': Timestamp.fromDate(bedtime),
                      'wakeTime': Timestamp.fromDate(wakeTime),
                      'durationMinutes': wakeTime.difference(bedtime).inMinutes,
                      'quality': quality,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  }
                : null,
            child: const Text('Yadda saxla'),
          ),
        ],
      ),
    ),
  );
}
