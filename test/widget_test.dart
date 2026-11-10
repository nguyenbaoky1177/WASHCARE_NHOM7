import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washcare/core/app_colors.dart';
import 'package:washcare/widgets/order/order_checkout_bar.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final language in ['vi', 'en']) {
      testWidgets('Checkout fits narrow screens in ${brightness.name}/$language',
          (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            supportedLocales: const [Locale('vi'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.8),
              ),
              child: child!,
            ),
            home: Scaffold(
              bottomNavigationBar: OrderCheckoutBar(
                total: '1.000.000 đ',
                submitting: false,
                onSubmit: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(language == 'vi' ? 'Xác nhận đặt đơn' : 'Confirm order'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final brightness in Brightness.values) {
    testWidgets('Readable WashCare card colors in ${brightness.name} mode',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: primaryBlue,
              brightness: brightness,
            ),
          ),
          home: Builder(builder: (context) {
            expect(context.isDarkTheme, brightness == Brightness.dark);
            for (final foreground in [
              context.headingColor,
              context.mutedColor,
              context.accentColor,
            ]) {
              final text = foreground.a == 1.0
                  ? foreground
                  : Color.alphaBlend(foreground, context.cardSurface);
              final luminances = [
                text.computeLuminance(),
                context.cardSurface.computeLuminance(),
              ]..sort();
              expect((luminances.last + 0.05) / (luminances.first + 0.05),
                  greaterThanOrEqualTo(4.5));
            }
            return const SizedBox.shrink();
          }),
        ),
      );
    });
  }

  test('App colors are correctly configured', () {
    expect(primaryBlue, const Color(0xFF2563EB));
    expect(paleBlue, const Color(0xFFEFF6FF));
    expect(darkBlue, const Color(0xFF0F2744));
    expect(backgroundColor, const Color(0xFFF8FAFC));
  });

  testWidgets('App theme configuration smoke test', (
    WidgetTester tester,
  ) async {
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: primaryBlue),
      scaffoldBackgroundColor: backgroundColor,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(body: Center(child: Text('WashCare'))),
      ),
    );

    expect(find.text('WashCare'), findsOneWidget);
  });
}
