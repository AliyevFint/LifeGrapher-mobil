import 'package:flutter_test/flutter_test.dart';
import 'package:lifegrapher_mobile/main.dart';

void main() {
  testWidgets('App starts with a blank page', (tester) async {
    await tester.pumpWidget(const LifeGrapherApp());
    expect(find.byType(LifeGrapherApp), findsOneWidget);
  });
}
