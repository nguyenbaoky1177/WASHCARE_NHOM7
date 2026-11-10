import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../models/order_model.dart';

class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({
    super.key,
    required this.order,
    this.showIcon = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    this.backgroundAlpha = 0.10,
    this.radius = 20,
    this.fontSize = 12,
  });

  final OrderModel order;
  final bool showIcon;
  final EdgeInsets padding;
  final double backgroundAlpha;
  final double radius;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final color = context.isDarkTheme
        ? Color.lerp(order.statusColor, Colors.white, 0.45)!
        : order.statusColor;
    final label = Text(
      order.statusLabel(
        english: Localizations.localeOf(context).languageCode == 'en',
      ),
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: fontSize,
      ),
    );

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: backgroundAlpha),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: showIcon
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(order.statusIcon, size: 16, color: color),
                const SizedBox(width: 6),
                label,
              ],
            )
          : label,
    );
  }
}
