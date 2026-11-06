import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

class MomoPaymentException implements Exception {
  const MomoPaymentException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MomoPaymentService {
  static Future<Map<String, dynamic>> request(
    String action, {
    int? orderId,
  }) async {
    try {
      final response = await supabase.functions
          .invoke('momo-payment', body: {'action': action, 'order_id': orderId})
          .timeout(const Duration(seconds: 50));
      return Map<String, dynamic>.from(response.data as Map);
    } on FunctionException catch (error) {
      final details = error.details;
      final message = details is Map ? details['message']?.toString() : null;
      throw MomoPaymentException(
        message ?? 'MoMo Sandbox chưa sẵn sàng. Vui lòng thử lại sau.',
      );
    } on TimeoutException {
      throw const MomoPaymentException(
        'Chưa nhận được phản hồi. Hãy kiểm tra trạng thái trước khi thử lại.',
      );
    } catch (_) {
      throw const MomoPaymentException(
        'Không kết nối được MoMo Sandbox. Vui lòng kiểm tra mạng và thử lại.',
      );
    }
  }
}
