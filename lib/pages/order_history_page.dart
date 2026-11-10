import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_settings.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'customer_order_detail_page.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  final _supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _loadOrders();
  }

  Future<List<Map<String, dynamic>>> _loadOrders() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final result = await _supabase
        .from('orders')
        .select('*, order_items(*, services(name, unit))')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(result);
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'Chưa có thông tin';
    final date = DateTime.tryParse(value.toString())?.toLocal();
    if (date == null) return value.toString();
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatPrice(dynamic value) {
    final price = double.tryParse(value?.toString() ?? '') ?? 0;
    return '${price.toStringAsFixed(0)} đ';
  }

  String _statusText(dynamic status) {
    switch (status?.toString()) {
      case 'pending':
        return 'Chờ xác nhận';
      case 'confirmed':
        return 'Đã xác nhận';
      case 'washing':
        return 'Đang giặt sấy';
      case 'delivering':
        return 'Đang giao hàng';
      case 'completed':
        return 'Hoàn thành';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return status?.toString() ?? 'Không rõ';
    }
  }

  Color _statusColor(dynamic status) {
    switch (status?.toString()) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'washing':
        return Colors.orange;
      case 'delivering':
        return Colors.teal;
      case 'confirmed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Future<void> _refreshOrders() async {
    setState(() => _ordersFuture = _loadOrders());
    await _ordersFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageSurface,
      appBar: AppBar(
        title: Text(
          AppSettings.text(context, 'Lịch sử đơn hàng', 'Order history'),
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Không tải được lịch sử đơn hàng.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _refreshOrders,
                      child: const Text('Thử lại'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          final orders = snapshot.data ?? [];
          if (orders.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refreshOrders,
              child: ListView(
                children: const [
                  SizedBox(height: 140),
                  Icon(Icons.receipt_long, size: 72, color: Colors.grey),
                  SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Bạn chưa có đơn hàng nào.',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshOrders,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                final items = order['order_items'] as List? ?? [];
                final status = order['status'];
                final color = _statusColor(status);

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  color: context.cardSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      final orderModel = OrderModel.fromJson(order);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CustomerOrderDetailPage(order: orderModel),
                        ),
                      );
                      _refreshOrders();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.receipt_long,
                                color: Color(0xFF1976D2),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Đơn hàng #${order['id']}',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _statusText(status),
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Text('Ngày đặt: ${_formatDate(order['created_at'])}'),
                          const SizedBox(height: 8),
                          Text('Người nhận: ${order['customer_name'] ?? ''}'),
                          const SizedBox(height: 8),
                          Text('Số điện thoại: ${order['phone'] ?? ''}'),
                          const SizedBox(height: 8),
                          Text('Địa chỉ: ${order['address'] ?? ''}'),
                          const SizedBox(height: 12),
                          const Text(
                            'Dịch vụ đã đặt',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          if (items.isEmpty)
                            const Text('Không có thông tin dịch vụ.')
                          else
                            ...items.map((item) {
                              final service = item['services'];
                              final name = service is Map
                                  ? service['name']?.toString() ?? 'Dịch vụ'
                                  : 'Dịch vụ';
                              final unit = service is Map
                                  ? service['unit']?.toString() ?? ''
                                  : '';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('• '),
                                    Expanded(
                                      child: Text(
                                        '$name — ${item['quantity']} $unit',
                                      ),
                                    ),
                                    Text(
                                      _formatPrice(item['subtotal']),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Tổng tiền',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                _formatPrice(order['total_price']),
                                style: const TextStyle(
                                  color: Color(0xFF1976D2),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                          if ((order['note'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text('Ghi chú: ${order['note']}'),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            'Thời gian nhận: ${_formatDate(order['pickup_time'])}',
                            style: TextStyle(color: context.mutedColor),
                          ),
                          const Divider(height: 24),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'Xem chi tiết tiến trình & thanh toán',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF1976D2),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 12,
                                color: Color(0xFF1976D2),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
