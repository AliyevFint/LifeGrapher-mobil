import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifegrapher_mobile/main.dart';

void main() {
  testWidgets('App shell renders a supplied home page', (tester) async {
    await tester.pumpWidget(
      const LifeGrapherApp(
        home: Scaffold(body: Center(child: Text('Test ekranı'))),
      ),
    );

    expect(find.text('Test ekranı'), findsOneWidget);
  });
}
