import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_settings.dart';

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
        color: context.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.cardOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chi tiết thanh toán',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: context.headingColor,
            ),
          ),
          const Divider(height: 20),
          _summaryRow(context, 'Tiền dịch vụ', subtotal),
          _summaryRow(
            context,
            'Phí vận chuyển',
            shippingFee ?? 'Miễn phí',
            highlight: shippingFee == null,
          ),
          if (discount != null)
            _summaryRow(context, 'Giảm giá ($voucherCode)', discount!, highlight: true),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppSettings.text(context, 'Tổng thanh toán', 'Order total'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: context.headingColor,
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

  Widget _summaryRow(BuildContext context, String title, String val, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(color: context.mutedColor, fontSize: 13),
          ),
          Text(
            val,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: highlight ? Colors.green : context.detailColor,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
