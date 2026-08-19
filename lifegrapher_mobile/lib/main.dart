import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

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
    return const MaterialApp(
      title: 'LifeGrapher',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SizedBox.expand(),
        ),
      ),
    );
  }
}
