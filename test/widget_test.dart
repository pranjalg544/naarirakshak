// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:naarirakshak/main.dart';

void main() {
  test('mobile platforms declare the location permissions required for live GPS tracking', () {
    final androidManifest = File('android/app/src/main/AndroidManifest.xml');
    final iosInfoPlist = File('ios/Runner/Info.plist');

    expect(androidManifest.existsSync(), isTrue,
        reason: 'Android manifest is missing.');
    final androidContent = androidManifest.readAsStringSync();
    expect(androidContent.contains('android.permission.ACCESS_FINE_LOCATION'), isTrue,
        reason: 'ACCESS_FINE_LOCATION is required for GPS detection.');
    expect(androidContent.contains('android.permission.ACCESS_COARSE_LOCATION'), isTrue,
        reason: 'ACCESS_COARSE_LOCATION is required for coarse fallback on Android.');

    expect(iosInfoPlist.existsSync(), isTrue,
        reason: 'iOS Info.plist is missing.');
    final iosContent = iosInfoPlist.readAsStringSync();
    expect(iosContent.contains('NSLocationWhenInUseUsageDescription'), isTrue,
        reason: 'iOS needs a location usage description for live tracking.');
  });

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

    expect(find.textContaining('Good '), findsOneWidget);
    expect(find.text('Priya Kapoor'), findsOneWidget);
    expect(find.text('Ready for your commute'), findsOneWidget);
  });
}
