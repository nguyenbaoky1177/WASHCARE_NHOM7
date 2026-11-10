import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:washcare/pages/order_page.dart';

import 'test_supabase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const customer = 'checkout-test-customer';
  final submissions = <Map<String, dynamic>>[];

  setUpAll(() async {
    await initializeTestSupabase(
      handler: (request) async {
        switch (request.url.path) {
          case '/rest/v1/profiles':
            return http.Response(
              jsonEncode([
                {
                  'id': customer,
                  'full_name': 'Test Customer',
                  'phone': '0901234567',
                  'role': 'customer',
                },
              ]),
              200,
            );
          case '/rest/v1/services':
            return http.Response(
              jsonEncode([
                {
                  'id': 1,
                  'name': 'Laundry',
                  'price': 80000,
                  'unit': 'kg',
                  'is_active': true,
                },
              ]),
              200,
            );
          case '/rest/v1/rpc/create_order_v2':
            submissions.add(jsonDecode(request.body) as Map<String, dynamic>);
            return http.Response('{"id":42,"total_price":95000}', 200);
          default:
            return http.Response(
              jsonEncode({
                'message': 'Unexpected request: ${request.url.path}',
              }),
              400,
            );
        }
      },
    );
    await signInTestUser(customer);
  });

  testWidgets('customer books a COD order through the checkout UI', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: OrderPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final contactFields = find.byType(TextFormField);
    await tester.enterText(contactFields.at(2), '42 Test Street');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm order'));
    await tester.pump(const Duration(seconds: 1));

    expect(submissions, hasLength(1));
    expect(find.text('Order placed!'), findsOneWidget);
    final order = submissions.single;
    expect(order['p_payment_method'], 'cod');
    expect(order['p_items'], [
      {'service_id': 1, 'quantity': 1},
    ]);
    expect(order['p_address'], '42 Test Street');
    expect(
      DateTime.parse(order['p_pickup_time'] as String).isAfter(DateTime.now()),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
