import '../../core/request_timeout.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/order_status_badge.dart';
import '../../core/app_colors.dart';
import '../../core/supabase_client.dart';
import '../../models/models.dart';
import 'admin_order_detail_page.dart';

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  late Future<List<OrderModel>> _ordersFuture;
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all';
  String _searchQuery = '';
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _loadAllOrders();
    _setupRealtime();
  }

  @override
  void dispose() {
    _searchController.dispose();
    if (_realtimeChannel != null) {
      supabase.removeChannel(_realtimeChannel!);
    }
    super.dispose();
  }

  void _setupRealtime() {
    final channelName =
        'admin_all_orders_${DateTime.now().millisecondsSinceEpoch}';
    _realtimeChannel = supabase.channel(channelName);

    _realtimeChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (payload) {
            if (!mounted) return;

            if (payload.eventType == PostgresChangeEvent.insert) {
              final newRecord = payload.newRecord;
              final customerName =
                  newRecord['customer_name']?.toString() ?? 'Khách';
              final id = newRecord['id']?.toString() ?? '';

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF17365D),
                  content: Row(
                    children: [
                      const Icon(
                        Icons.notifications_active,
                        color: Colors.amber,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '🔔 Đơn hàng mới #$id từ $customerName!',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  duration: const Duration(seconds: 4),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }

            _refresh();
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed && mounted) {
            _refresh();
          }
        });
  }

  Future<List<OrderModel>> _loadAllOrders() async {
    // Admin loads ALL orders across the entire database without user_id filter
    final result = await supabase
        .from('orders')
        .select('*, order_items(*, services(name, unit))')
        .order('created_at', ascending: false)
        .timeout(supabaseRequestTimeout);

    return (result as List)
        .whereType<Map<String, dynamic>>()
        .map((item) => OrderModel.fromJson(item))
        .toList();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final future = _loadAllOrders();
    setState(() {
      _ordersFuture = future;
    });
    try {
      await future;
    } catch (_) {}
  }

  List<OrderModel> _filterOrders(List<OrderModel> orders) {
    var list = orders;

    // Filter by status
    switch (_selectedFilter) {
      case 'pending':
        list = list.where((o) => o.status == 'pending').toList();
        break;
      case 'confirmed':
        list = list.where((o) => o.status == 'confirmed').toList();
        break;
      case 'delivering':
        list = list.where((o) => o.status == 'delivering').toList();
        break;
      case 'washing':
        list = list.where((o) => o.status == 'washing').toList();
        break;
      case 'completed':
        list = list.where((o) => o.status == 'completed').toList();
        break;
      case 'cancelled':
        list = list.where((o) => o.status == 'cancelled').toList();
        break;
      default:
        break;
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((o) {
        final nameMatch = o.customerName.toLowerCase().contains(q);
        final phoneMatch = o.phone.contains(q);
        final idMatch = o.id.toString().contains(q);
        final addressMatch = o.address.toLowerCase().contains(q);
        return nameMatch || phoneMatch || idMatch || addressMatch;
      }).toList();
    }

    return list;
  }

  int _countByStatus(List<OrderModel> orders, String status) {
    if (status == 'all') return orders.length;
    return orders.where((o) => o.status == status).length;
  }

  Future<void> _quickUpdateStatus(
    OrderModel order,
    String newStatus,
    String label,
  ) async {
    try {
      await supabase.rpc(
        'admin_update_order_status',
        params: {
          'p_order_id': order.id,
          'p_new_status': newStatus,
          'p_note': label,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đơn #${order.id} ➔ $label'),
          backgroundColor: const Color(0xFF16845B),
        ),
      );
      _refresh();
    } catch (e) {
      if (!mounted) return;
      final errStr = e.toString().toLowerCase();
      String msg = 'Lỗi cập nhật: $e';
      if (errStr.contains('admin') ||
          errStr.contains('permission') ||
          errStr.contains('42501')) {
        msg =
            'Lỗi: Tài khoản chưa có role="admin" trong bảng profiles Supabase.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red[800],
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _makeCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openMaps(String address) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildFilterChips(List<OrderModel> orders) {
    const filters = [
      ('all', 'Tất cả'),
      ('pending', 'Chờ duyệt'),
      ('confirmed', 'Đã tiếp nhận'),
      ('washing', 'Đang giặt'),
      ('delivering', 'Đang giao'),
      ('completed', 'Hoàn thành'),
      ('cancelled', 'Đã hủy'),
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final selected = _selectedFilter == filter.$1;
          final count = _countByStatus(orders, filter.$1);

          return ChoiceChip(
            selected: selected,
            showCheckmark: false,
            label: Text('${filter.$2} ($count)'),
            selectedColor: darkBlue,
            backgroundColor: context.cardSurface,
            side: BorderSide(
              color: selected ? darkBlue : context.cardOutline,
            ),
            labelStyle: TextStyle(
              color: selected ? Colors.white : context.mutedColor,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
            onSelected: (_) {
              setState(() => _selectedFilter = filter.$1);
            },
          );
        },
      ),
    );
  }

  Widget _buildAdminOrderCard(OrderModel order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: context.cardSurface,
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE4ECF5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminOrderDetailPage(order: order),
            ),
          );
          _refresh();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: order.statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          order.statusIcon,
                          color: order.statusColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Đơn #${order.id}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: context.headingColor,
                            ),
                          ),
                          Text(
                            order.formattedCreatedAt,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.mutedColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  OrderStatusBadge(order: order),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.blueGrey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      order.customerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.phone,
                      color: Colors.green,
                      size: 20,
                    ),
                    tooltip: 'Gọi điện',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                    onPressed: () => _makeCall(order.phone),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(
                      Icons.directions,
                      color: primaryBlue,
                      size: 20,
                    ),
                    tooltip: 'Chỉ đường',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                    onPressed: () => _openMaps(order.address),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Colors.blueGrey,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      order.address,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.detailColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.blueGrey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Lấy đồ: ${order.formattedPickupTime}',
                    style: TextStyle(fontSize: 12, color: context.mutedColor),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${order.items.length} món đồ',
                    style: TextStyle(color: context.mutedColor, fontSize: 13),
                  ),
                  Text(
                    order.formattedTotalPrice,
                    style: TextStyle(
                      color: context.accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (order.status == 'pending')
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: primaryBlue, foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: () => _quickUpdateStatus(
                          order,
                          'confirmed',
                          'Đã tiếp nhận',
                        ),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Tiếp nhận'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                      ),
                      onPressed: order.canCancel
                          ? () =>
                                _quickUpdateStatus(order, 'cancelled', 'Đã hủy')
                          : null,
                      child: const Text('Từ chối'),
                    ),
                  ],
                )
              else if (order.status == 'confirmed')
                FilledButton.icon(
                  onPressed: () =>
                      _quickUpdateStatus(order, 'washing', 'Bắt đầu giặt sấy'),
                  icon: const Icon(Icons.local_laundry_service),
                  label: const Text('Bắt đầu giặt sấy'),
                )
              else if (order.status == 'washing')
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF16845B),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () => _quickUpdateStatus(
                      order,
                      'delivering',
                      'Bắt đầu giao hàng',
                    ),
                    icon: const Icon(Icons.task_alt, size: 16),
                    label: const Text('Bắt đầu giao hàng'),
                  ),
                )
              else if (order.status == 'delivering')
                FilledButton.icon(
                  onPressed: () =>
                      _quickUpdateStatus(order, 'completed', 'Đã giao hàng'),
                  icon: const Icon(Icons.task_alt),
                  label: const Text('Xác nhận đã giao'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageSurface,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings, color: Colors.amber),
            SizedBox(width: 8),
            Text(
              'Quản trị Đơn hàng',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: darkBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<List<OrderModel>>(
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
                    const Text('Không tải được danh sách đơn toàn hệ thống.'),
                    const SizedBox(height: 6),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.mutedColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _refresh,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }

          final allOrders = snapshot.data ?? [];
          final displayedOrders = _filterOrders(allOrders);

          return Column(
            children: [
              Container(
                color: context.cardSurface,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm theo Tên khách, SĐT, Mã đơn, Địa chỉ...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: context.insetSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 16,
                    ),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val.trim());
                  },
                ),
              ),
              const SizedBox(height: 8),
              _buildFilterChips(allOrders),
              const SizedBox(height: 8),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: displayedOrders.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 80),
                            Icon(Icons.inbox, size: 64, color: Colors.blueGrey),
                            SizedBox(height: 12),
                            Center(
                              child: Text(
                                'Không tìm thấy đơn hàng nào',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                          itemCount: displayedOrders.length,
                          itemBuilder: (context, index) {
                            return _buildAdminOrderCard(displayedOrders[index]);
                          },
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
