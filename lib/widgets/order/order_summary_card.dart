import 'package:flutter/material.dart';

import '../../core/app_colors.dart';

class OrderSummaryCard extends StatelessWidget {
  const OrderSummaryCard({
    super.key,
    required this.subtotal,
    required this.total,
    this.shippingFee,
    this.discount,
    this.voucherCode,
  });

  final String subtotal;
  final String total;
  final String? shippingFee;
  final String? discount;
  final String? voucherCode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4ECF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chi tiết thanh toán',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: darkBlue,
            ),
          ),
          const Divider(height: 20),
          _summaryRow('Tiền dịch vụ', subtotal),
          _summaryRow(
            'Phí vận chuyển',
            shippingFee ?? 'Miễn phí',
            highlight: shippingFee == null,
          ),
          if (discount != null)
            _summaryRow('Giảm giá ($voucherCode)', discount!, highlight: true),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tổng thanh toán',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: darkBlue,
                ),
              ),
              Text(
                total,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: primaryBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String title, String val, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
          Text(
            val,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: highlight ? Colors.green : Colors.black87,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
