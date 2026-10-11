
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ActiveOrdersPage extends StatefulWidget {
  const ActiveOrdersPage({super.key});

  @override
  State<ActiveOrdersPage> createState() => _ActiveOrdersPageState();
}

class _ActiveOrdersPageState extends State<ActiveOrdersPage> {
  final _supabase = Supabase.instance.client;

  late Future<List<Map<String, dynamic>>> _ordersFuture;
  String _selectedFilter = 'all';
  final Set<String> _cancellingOrders = {};

  static const Color _primary = Color(0xFF1976D2);
  static const Color _background = Color(0xFFF4F7FB);

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

  Future<void> _refreshOrders() async {
    if (!mounted) return;

    final future = _loadOrders();

    setState(() {
      _ordersFuture = future;
    });

    try {
      await future;
    } catch (_) {
      // FutureBuilder hiển thị lỗi tải dữ liệu.
    }
  }

  List<Map<String, dynamic>> _filterOrders(
      List<Map<String, dynamic>> orders,
      ) {
    switch (_selectedFilter) {
      case 'active':
        return orders
            .where((o) =>
            ['pending', 'confirmed', 'processing'].contains(o['status']))
            .toList();
      case 'completed':
        return orders.where((o) => o['status'] == 'completed').toList();
      case 'cancelled':
        return orders.where((o) => o['status'] == 'cancelled').toList();
      default:
        return orders;
    }
  }

  String _statusText(dynamic status) {
    switch (status?.toString()) {
      case 'pending':
        return 'Chờ xác nhận';
      case 'confirmed':
        return 'Đã xác nhận';
      case 'processing':
        return 'Đang xử lý';
      case 'completed':
        return 'Hoàn thành';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return 'Không xác định';
    }
  }

  Color _statusColor(dynamic status) {
    switch (status?.toString()) {
      case 'pending':
        return const Color(0xFFED8B00);
      case 'confirmed':
        return const Color(0xFF1976D2);
      case 'processing':
        return const Color(0xFF7952B3);
      case 'completed':
        return const Color(0xFF16845B);
      case 'cancelled':
        return const Color(0xFFD64545);
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(dynamic status) {
    switch (status?.toString()) {
      case 'pending':
        return Icons.schedule;
      case 'confirmed':
        return Icons.check_circle_outline;
      case 'processing':
        return Icons.local_laundry_service_outlined;
      case 'completed':
        return Icons.task_alt;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline;
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'Chưa có thông tin';

    final date = DateTime.tryParse(value.toString())?.toLocal();
    if (date == null) return value.toString();

    String two(int n) => n.toString().padLeft(2, '0');

    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  String _formatPrice(dynamic value) {
    final price = double.tryParse(value?.toString() ?? '') ?? 0;
    return '${price.toStringAsFixed(0)} đ';
  }

  int _countOrders(List<Map<String, dynamic>> orders, String filter) {
    switch (filter) {
      case 'active':
        return orders
            .where((o) =>
            ['pending', 'confirmed', 'processing'].contains(o['status']))
            .length;
      case 'completed':
        return orders.where((o) => o['status'] == 'completed').length;
      case 'cancelled':
        return orders.where((o) => o['status'] == 'cancelled').length;
      default:
        return orders.length;
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _cancelOrder(Map<String, dynamic> order) async {
    if (order['status'] != 'pending') {
      _showMessage('Chỉ có thể hủy đơn đang chờ xác nhận.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận hủy đơn'),
        content: Text(
          'M có chắc muốn hủy đơn hàng #${order['id']} không? '
              'Thao tác này sẽ cập nhật trạng thái đơn.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Không'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xác nhận hủy'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final user = _supabase.auth.currentUser;
    if (user == null) {
      _showMessage('Phiên đăng nhập đã hết hạn.');
      return;
    }

    final orderId = order['id'].toString();

    if (_cancellingOrders.contains(orderId)) return;

    setState(() {
      _cancellingOrders.add(orderId);
    });

    var cancelledSuccessfully = false;

    try {
      final updated = await _supabase
          .from('orders')
          .update({'status': 'cancelled'})
          .eq('id', order['id'])
          .eq('user_id', user.id)
          .eq('status', 'pending')
          .select('id');

      if (!mounted) return;

      if (updated.isEmpty) {
        _showMessage(
          'Không thể hủy đơn. Có thể trạng thái đơn đã thay đổi '
              'hoặc bạn không có quyền cập nhật đơn này.',
        );
      } else {
        cancelledSuccessfully = true;
        _showMessage('Đã hủy đơn hàng #$orderId.');
      }
    } catch (e) {
      _showMessage('Hủy đơn thất bại: $e');
    } finally {
      if (mounted) {
        setState(() {
          _cancellingOrders.remove(orderId);
        });
      }
    }

    if (cancelledSuccessfully && mounted) {
      await _refreshOrders();
    }
  }

  Widget _buildFilter(List<Map<String, dynamic>> orders) {
    const filters = [
      ('all', 'Tất cả'),
      ('active', 'Đang xử lý'),
      ('completed', 'Hoàn thành'),
      ('cancelled', 'Đã hủy'),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final selected = _selectedFilter == filter.$1;

          return ChoiceChip(
            selected: selected,
            showCheckmark: false,
            label: Text(
              '${filter.$2} (${_countOrders(orders, filter.$1)})',
            ),
            selectedColor: _primary,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected ? _primary : const Color(0xFFDDE5EF),
            ),
            labelStyle: TextStyle(
              color: selected ? Colors.white : const Color(0xFF44546A),
              fontWeight:
              selected ? FontWeight.w600 : FontWeight.normal,
            ),
            onSelected: (_) {
              setState(() {
                _selectedFilter = filter.$1;
              });
            },
          );
        },
      ),
    );
  }

  Future<void> _openOrderDetail(
      Map<String, dynamic> order,
      ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailPage(
          order: Map<String, dynamic>.from(order),
          onCancel: () => _cancelOrder(order),
        ),
      ),
    );

    if (mounted) {
      await _refreshOrders();
    }
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status'];
    final color = _statusColor(status);
    final items = order['order_items'] as List? ?? [];
    final orderId = order['id'].toString();
    final cancelling = _cancellingOrders.contains(orderId);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE7EDF5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openOrderDetail(order),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.local_laundry_service_outlined,
                      color: _primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đơn hàng #${order['id']}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF24364B),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _formatDate(order['created_at']),
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_statusIcon(status), size: 14, color: color),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _statusText(status),
                              style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),
              _infoRow(
                Icons.person_outline,
                order['customer_name']?.toString().isNotEmpty == true
                    ? order['customer_name'].toString()
                    : 'Chưa có tên người nhận',
              ),
              const SizedBox(height: 10),
              _infoRow(
                Icons.location_on_outlined,
                order['address']?.toString().isNotEmpty == true
                    ? order['address'].toString()
                    : 'Chưa có địa chỉ',
              ),
              const SizedBox(height: 16),
              const Text(
                'DỊCH VỤ',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              if (items.isEmpty)
                const Text(
                  'Chưa có thông tin dịch vụ.',
                  style: TextStyle(color: Colors.black54),
                )
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
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.checkroom_outlined,
                          size: 17,
                          color: _primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(name)),
                        Text(
                          '${item['quantity'] ?? 0} $unit',
                          style: const TextStyle(color: Colors.black54),
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
                    'Tổng thanh toán',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      _formatPrice(order['total_price']),
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: _primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _infoRow(
                Icons.access_time,
                'Thời gian nhận: ${_formatDate(order['pickup_time'])}',
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Nhấn để xem chi tiết  ›',
                  style: TextStyle(
                    color: _primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (status == 'pending') ...[
                const Divider(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed:
                    cancelling ? null : () => _cancelOrder(order),
                    icon: cancelling
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                        : const Icon(Icons.cancel_outlined),
                    label: Text(
                      cancelling ? 'Đang hủy...' : 'Hủy đơn hàng',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.black54),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 100),
        Icon(
          Icons.receipt_long_outlined,
          size: 76,
          color: Colors.blueGrey.shade200,
        ),
        const SizedBox(height: 18),
        const Center(
          child: Text(
            'Chưa có đơn hàng phù hợp',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Thử chọn bộ lọc khác hoặc kéo xuống để làm mới.',
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text(
          'Đơn hàng',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
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
                      'Không tải được danh sách đơn hàng.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _refreshOrders,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }

          final orders = snapshot.data ?? [];
          final filteredOrders = _filterOrders(orders);

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 16, bottom: 14),
                color: _background,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Theo dõi đơn giặt ủi của bạn',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildFilter(orders),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshOrders,
                  child: filteredOrders.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: filteredOrders.length,
                    itemBuilder: (context, index) =>
                        _buildOrderCard(filteredOrders[index]),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class OrderDetailPage extends StatelessWidget {
  final Map<String, dynamic> order;
  final Future<void> Function() onCancel;

  const OrderDetailPage({
    super.key,
    required this.order,
    required this.onCancel,
  });

  static const Color _primary = Color(0xFF1976D2);

  String _statusText(dynamic status) {
    switch (status?.toString()) {
      case 'pending':
        return 'Chờ xác nhận';
      case 'confirmed':
        return 'Đã xác nhận';
      case 'processing':
        return 'Đang xử lý';
      case 'completed':
        return 'Hoàn thành';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return 'Không xác định';
    }
  }

  Color _statusColor(dynamic status) {
    switch (status?.toString()) {
      case 'pending':
        return const Color(0xFFED8B00);
      case 'confirmed':
        return const Color(0xFF1976D2);
      case 'processing':
        return const Color(0xFF7952B3);
      case 'completed':
        return const Color(0xFF16845B);
      case 'cancelled':
        return const Color(0xFFD64545);
      default:
        return Colors.grey;
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'Chưa có thông tin';

    final date = DateTime.tryParse(value.toString())?.toLocal();
    if (date == null) return value.toString();

    String two(int n) => n.toString().padLeft(2, '0');

    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  String _formatPrice(dynamic value) {
    final price = double.tryParse(value?.toString() ?? '') ?? 0;
    return '${price.toStringAsFixed(0)} đ';
  }

  Widget _detailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              title,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Chưa có thông tin' : value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = order['status'];
    final items = order['order_items'] as List? ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: Text('Chi tiết đơn #${order['id']}'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xFFE4ECF5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TRẠNG THÁI ĐƠN HÀNG',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Text(
                      _statusText(status),
                      style: TextStyle(
                        color: _statusColor(status),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(height: 32),
                  _detailRow('Mã đơn', '#${order['id']}'),
                  _detailRow('Ngày đặt', _formatDate(order['created_at'])),
                  _detailRow(
                    'Thời gian nhận',
                    _formatDate(order['pickup_time']),
                  ),
                  _detailRow(
                    'Người nhận',
                    order['customer_name']?.toString() ?? '',
                  ),
                  _detailRow(
                    'Địa chỉ',
                    order['address']?.toString() ?? '',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xFFE4ECF5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DỊCH VỤ ĐÃ ĐẶT',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (items.isEmpty)
                    const Text('Chưa có thông tin dịch vụ.')
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
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.local_laundry_service_outlined,
                              color: _primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${item['quantity'] ?? 0} $unit',
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      );
                    }),
                  const Divider(height: 28),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Tổng thanh toán',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        _formatPrice(order['total_price']),
                        style: const TextStyle(
                          color: _primary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (status == 'pending') ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  await onCancel();
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Hủy đơn hàng'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bạn chỉ có thể hủy đơn khi đơn đang chờ xác nhận.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black54,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
