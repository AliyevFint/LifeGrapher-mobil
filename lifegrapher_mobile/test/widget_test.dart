import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifegrapher_mobile/main.dart';

void main() {
  test('Mistyped admin ID is rejected without a database lookup', () async {
    expect(await UserService.findEmailForLoginId('345555'), isNull);
  });

  test('Admin ID resolves without requiring Firestore', () async {
    expect(
      await UserService.findEmailForLoginId('34555'),
      'ismayil.aliyevev@gmail.com',
    );
  });

  testWidgets('App shell renders a supplied home page', (tester) async {
    await tester.pumpWidget(
      const LifeGrapherApp(
        home: Scaffold(body: Center(child: Text('Test ekranı'))),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Test ekranı'), findsOneWidget);
  });
}
