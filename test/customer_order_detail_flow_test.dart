import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washcare/models/order_model.dart';
import 'package:washcare/pages/customer_order_detail_page.dart';

import 'test_supabase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeTestSupabase();
    await signInTestUser('detail-test-customer');
  });

  Future<void> openOrder(WidgetTester tester, OrderModel order) async {
    await tester.binding.setSurfaceSize(const Size(800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: CustomerOrderDetailPage(order: order)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> closeOrder(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 1));
  }

  testWidgets(
    'cancelled orders show cancellation instead of a pending timeline',
    (tester) async {
      await openOrder(
        tester,
        const OrderModel(
          id: 1,
          userId: 'detail-test-customer',
          customerName: 'Test',
          phone: '',
          address: '',
          status: 'cancelled',
          totalPrice: 75000,
        ),
      );
      expect(find.text('Order #1'), findsWidgets);
      expect(
        find.text('Cancelled'),
        findsOneWidget,
      );
      expect(find.text('Awaiting confirmation'), findsNothing);
      await closeOrder(tester);
    },
  );

  testWidgets('customer sees recorded payment for a collected COD order', (
    tester,
  ) async {
    await openOrder(
      tester,
      OrderModel.fromJson({
        'id': 2,
        'user_id': 'detail-test-customer',
        'status': 'completed',
        'payment_method': 'cod',
        'total_price': 75000,
        'cod_collected_at': '2026-11-10T12:00:00Z',
        'cod_collected_amount': 75000,
      }),
    );
    expect(find.text('Payment recorded'), findsOneWidget);
    expect(find.text('Collection not recorded'), findsNothing);
    await closeOrder(tester);
  });
}
