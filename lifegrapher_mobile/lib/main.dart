import 'package:flutter/material.dart';

void main() {
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
