import 'package:flutter/material.dart';

import '../models/order_model.dart';
import 'momo_payment_dialog.dart';

class MomoPaymentCard extends StatelessWidget {
  const MomoPaymentCard({
    super.key,
    required this.order,
    this.allowPayment = true,
    this.onClosed,
  });

  final OrderModel order;
  final bool allowPayment;
  final Future<void> Function()? onClosed;

  @override
  Widget build(BuildContext context) {
    final legacyDemo = order.paymentMethod == 'momo_demo';
    return Card(
      color: const Color(0xFFFFF0F7),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              legacyDemo ? 'MoMo mô phỏng (đơn cũ)' : 'MoMo Sandbox',
              style: const TextStyle(
                color: Color(0xFFA50064),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text('Xem trạng thái thanh toán của đơn hàng.'),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                await MomoPaymentDialog.show(
                  context: context,
                  orderId: order.id,
                  amount: order.totalPrice,
                  allowPayment: allowPayment,
                  legacyDemo: legacyDemo,
                );
                await onClosed?.call();
              },
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: const Text('Xem thanh toán MoMo'),
            ),
          ],
        ),
      ),
    );
  }
}
