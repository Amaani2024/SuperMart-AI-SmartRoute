import 'package:flutter_test/flutter_test.dart';
import 'package:supermart_flutter/main.dart';

void main() {
  testWidgets('shows SuperMart login screen', (tester) async {
    await tester.pumpWidget(const SuperMartApp());

    expect(find.text('SuperMart AI'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}
