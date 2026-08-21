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
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const LifeGrapherApp());
}

class LifeGrapherApp extends StatelessWidget {
  const LifeGrapherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LifeGrapher',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        useMaterial3: true,
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
      final idRef = FirebaseFirestore.instance.collection('userIds').doc(loginId);
      final created = await FirebaseFirestore.instance.runTransaction((tx) async {
        final existingUser = await tx.get(ref);
        if (existingUser.data()?['loginId'] is String) {
          tx.set(ref, data, SetOptions(merge: true));
          return true;
        }
        final existingId = await tx.get(idRef);
        if (existingId.exists) return false;

        tx.set(idRef, {'uid': user.uid, 'createdAt': FieldValue.serverTimestamp()});
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
    final userSnapshot = await FirebaseFirestore.instance.collection('users').doc(uid).get();
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
            'invalid-credential' || 'wrong-password' => 'Gmail/ID nömrəsi və ya kod yanlışdır.',
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
        final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: identifier,
          password: password,
        );
        await UserService.upsertUser(credential.user!);
      } else {
        final email = identifier.contains('@')
            ? identifier
            : await UserService.findEmailForLoginId(identifier);
        if (email == null) throw Exception('Bu ID nömrəsi ilə hesab tapılmadı.');
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
    final controller = TextEditingController(text: _identifierController.text.trim());
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
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
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
      if (e.code == GoogleSignInExceptionCode.canceled) return;
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            children: [
              const SizedBox(height: 48),
              Image.asset('assets/logo.png', width: 120, height: 120),
              const SizedBox(height: 32),
              const Text(
                'LifeGrapher',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hayatını takip et',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _identifierController,
                keyboardType: _isRegistering ? TextInputType.emailAddress : TextInputType.text,
                decoration: const InputDecoration(
                  labelText: 'Gmail və ya ID nömrəsi',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                onSubmitted: (_) => _isBusy ? null : _signInWithEmailOrId(),
                decoration: const InputDecoration(
                  labelText: 'Kod',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _isBusy ? null : _signInWithEmailOrId,
                  child: _isBusy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isRegistering ? 'Qeydiyyatdan keç' : 'Daxil ol'),
                ),
              ),
              TextButton(
                onPressed: _isBusy
                    ? null
                    : () => setState(() => _isRegistering = !_isRegistering),
                child: Text(
                  _isRegistering
                      ? 'Hesabın var? Daxil ol'
                      : 'Yeni hesab yarat',
                ),
              ),
              TextButton(
                onPressed: _isBusy ? null : _sendPasswordResetEmail,
                child: const Text('Şifrəni unutdun? Gmail ilə yenilə'),
              ),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12), child: Text('və ya')),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
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
                        'Google ile giriş yap',
                        style: TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text(
              'Hoş geldin!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              user?.email ?? user?.uid ?? 'Kullanıcı',
              style: const TextStyle(color: Colors.grey),
            ),
            if (user != null)
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  final loginId = snapshot.data?.data()?['loginId'] as String?;
                  if (loginId == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      'Sizin giriş ID nömrəniz: $loginId',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
