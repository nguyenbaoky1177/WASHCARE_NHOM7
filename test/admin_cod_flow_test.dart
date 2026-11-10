import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:washcare/models/order_model.dart';
import 'package:washcare/pages/admin/admin_order_detail_page.dart';

import 'test_supabase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const admin = 'cod-test-admin';
  final order = <String, dynamic>{
    'id': 42,
    'user_id': 'cod-test-customer',
    'customer_name': 'Test Customer',
    'payment_method': 'cod',
    'status': 'completed',
    'total_price': 95000,
    'cod_collected_at': null,
    'cod_collected_by': null,
    'cod_collected_amount': null,
  };
  final confirmations = <Map<String, dynamic>>[];

  setUpAll(() async {
    await initializeTestSupabase(
      handler: (request) async {
        switch (request.url.path) {
          case '/rest/v1/rpc/admin_confirm_cod_collection':
            confirmations.add(jsonDecode(request.body) as Map<String, dynamic>);
            order.addAll({
              'cod_collected_at': '2026-11-10T10:00:00Z',
              'cod_collected_by': admin,
              'cod_collected_amount': 95000,
            });
            return http.Response('{}', 200);
          case '/rest/v1/orders':
            return http.Response(jsonEncode([order]), 200);
          default:
            return http.Response('{"message":"Unexpected request"}', 400);
        }
      },
    );
    await signInTestUser(admin);
  });

  testWidgets('admin records COD and sees the receipt after refresh', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: AdminOrderDetailPage(order: OrderModel.fromJson(order)),
      ),
    );
    await tester.pump();

    final action = find.text('Xác nhận đã thu tiền COD');
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(confirmations, isEmpty);
    await tester.tap(find.text('Đã thu đủ tiền'));
    await tester.pumpAndSettle();

    expect(confirmations, [
      {'p_order_id': 42},
    ]);
    expect(find.text('Đã thu COD: 95.000 đ'), findsOneWidget);
    expect(find.text('Mã admin ghi nhận: $admin'), findsOneWidget);
    expect(action, findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 1));
  });
}
