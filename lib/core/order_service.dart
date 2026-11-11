import 'package:supabase_flutter/supabase_flutter.dart';

import 'request_timeout.dart';
import 'supabase_client.dart';

class OrderService {
  static Future<bool> isFirstOrderEligible() async {
    final eligible = await supabase
        .rpc('is_first_order_eligible')
        .timeout(supabaseRequestTimeout);
    return eligible == true;
  }

  static Future<(int, double)> createOrder({
    required String customerName,
    required String phone,
    required String address,
    required DateTime pickupTime,
    required String note,
    required List<Map<String, dynamic>> items,
    required String deliveryType,
    required String paymentMethod,
    required String? voucherCode,
  }) async {
    final params = <String, dynamic>{
      'p_customer_name': customerName,
      'p_phone': phone,
      'p_address': address,
      'p_pickup_time': pickupTime.toUtc().toIso8601String(),
      'p_note': note,
      'p_items': items,
      'p_delivery_type': deliveryType,
      'p_payment_method': paymentMethod,
      'p_voucher_code': voucherCode,
    };

    Map<String, dynamic> order;
    try {
      order = await supabase.rpc<Map<String, dynamic>>(
        'create_order_v2',
        params: params,
      );
    } on PostgrestException catch (error) {
      if (paymentMethod != 'vietqr' || !error.message.contains('hợp lệ')) {
        rethrow;
      }
      order = await supabase.rpc<Map<String, dynamic>>(
        'create_order_v2',
        params: {...params, 'p_payment_method': 'cod'},
      );
    }
    return (
      (order['id'] as num).toInt(),
      (order['total_price'] as num).toDouble(),
    );
  }
}
