// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:naarirakshak/main.dart';

void main() {
  testWidgets('creating an account shows the account name on the dashboard', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const NariRakshakApp());

    expect(find.text('NaariRakshak'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Welcome back'), findsOneWidget);
    await tester.tap(find.text('New to NaariRakshak? Create an account'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Create your account'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'Priya Kapoor');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'priya@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'securepass');
    await tester.tap(find.text('Create account'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Good evening,'), findsOneWidget);
    expect(find.text('Priya Kapoor'), findsOneWidget);
    expect(find.text('Ready for your commute'), findsOneWidget);
  });
}
