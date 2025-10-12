// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:label_printer/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // 앱이 최소한 오류 없이 빌드되는지만 확인
    await tester.pumpWidget(const MaterialApp(home: StartupHomePage()));
    expect(find.byType(StartupHomePage), findsOneWidget);
  });
}
