import 'package:bypt_cal/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _tapKeys(WidgetTester tester, List<String> labels) async {
  for (final label in labels) {
    final String keyName = label == '='
        ? 'action-='
        : label == '⌫'
            ? 'action-⌫'
            : 'key-$label';
    await tester.tap(find.byKey(Key(keyName)), warnIfMissed: false);
    await tester.pumpAndSettle();
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('evaluates simple addition', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CalculatorScreen()));
    await _tapKeys(tester, ['2', '+', '3', '=']);
    final Text result = tester.widget<Text>(find.byKey(const Key('result-text')));
    expect(result.data, '5');
  });

  testWidgets('percentage operator works (50% == 0.5)', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CalculatorScreen()));
    await _tapKeys(tester, ['5', '0', '%', '=']);
    final Text result = tester.widget<Text>(find.byKey(const Key('result-text')));
    expect(result.data, '0.5');
  });

  testWidgets('scientific function sin(0) == 0', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CalculatorScreen()));
    await tester.tap(find.byIcon(Icons.science_rounded));
    await tester.pumpAndSettle();
    await _tapKeys(tester, ['sin', '0', ')', '=']);
    expect(find.text('0'), findsWidgets);
  });

  testWidgets('backspace removes last character', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CalculatorScreen()));
    await _tapKeys(tester, ['1', '2', '⌫', '=']);
    final Text result = tester.widget<Text>(find.byKey(const Key('result-text')));
    expect(result.data, '1');
  });

  testWidgets('clear all resets expression and result', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CalculatorScreen()));
    await _tapKeys(tester, ['9', '9', '+', '1']);
    await tester.tap(find.byTooltip('Clear all'));
    await tester.pumpAndSettle();
    await _tapKeys(tester, ['=']);
    expect(find.text('0'), findsWidgets);
  });

  testWidgets('history appends on evaluate and can be restored', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CalculatorScreen()));
    await _tapKeys(tester, ['2', '+', '2', '=']);
    await tester.tap(find.byTooltip('History'));
    await tester.pumpAndSettle();
    expect(find.text('2+2'), findsWidgets);
    expect(find.text('4'), findsWidgets);

    final Finder historyText = find.text('2+2').last;
    final Finder historyTile = find.ancestor(of: historyText, matching: find.byType(InkWell));
    await tester.ensureVisible(historyTile);
    await tester.tap(historyTile);
    await tester.pumpAndSettle();

    await _tapKeys(tester, ['=']);
    final Text result = tester.widget<Text>(find.byKey(const Key('result-text')));
    expect(result.data, '4');
  });

  testWidgets('clear history removes all entries', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CalculatorScreen()));
    await _tapKeys(tester, ['3', '×', '3', '=']);
    await tester.tap(find.byTooltip('History'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_sweep_rounded));
    await tester.pumpAndSettle();
    expect(find.text('No history yet'), findsOneWidget);
  });
}


