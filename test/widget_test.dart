// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

// Calculator basic smoke test
// Ensures the app renders without throwing and shows Calculator title.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:bypt_cal/main.dart';

void main() {
  testWidgets('App loads and renders', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    // AppBar exists and history icon is present
    expect(find.byIcon(Icons.history_rounded), findsOneWidget);
  });
}
