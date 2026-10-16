import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washcare/core/app_colors.dart';

void main() {
  test('App colors are correctly configured', () {
    expect(primaryBlue, const Color(0xFF2878D0));
    expect(paleBlue, const Color(0xFFEAF4FF));
    expect(darkBlue, const Color(0xFF17365D));
    expect(backgroundColor, const Color(0xFFF6F9FD));
  });

  testWidgets('App theme configuration smoke test', (WidgetTester tester) async {
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: primaryBlue),
      scaffoldBackgroundColor: backgroundColor,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(
          body: Center(
            child: Text('WashCare'),
          ),
        ),
      ),
    );

    expect(find.text('WashCare'), findsOneWidget);
  });
}
