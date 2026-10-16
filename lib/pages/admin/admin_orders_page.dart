import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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
    final channelName = 'admin_all_orders_${DateTime.now().millisecondsSinceEpoch}';
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
              final customerName = newRecord['customer_name']?.toString() ?? 'Khách';
              final id = newRecord['id']?.toString() ?? '';

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF17365D),
                  content: Row(
                    children: [
                      const Icon(Icons.notifications_active, color: Colors.amber, size: 22),
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
        .subscribe();
  }

  Future<List<OrderModel>> _loadAllOrders() async {
    // Admin loads ALL orders across the entire database without user_id filter
    final result = await supabase
        .from('orders')
        .select('*, order_items(*, services(name, unit))')
        .order('created_at', ascending: false);

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
      case 'processing':
        list = list.where((o) => o.status == 'processing').toList();
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

  Future<void> _quickUpdateStatus(OrderModel order, String newStatus, String label) async {
    try {
      await supabase
          .from('orders')
          .update({'status': newStatus})
          .eq('id', order.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đơn #${order.id} ➔ $label')),
      );
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi cập nhật: $e')),
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
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildFilterChips(List<OrderModel> orders) {
    const filters = [
      ('all', 'Tất cả'),
      ('pending', 'Chờ duyệt'),
      ('confirmed', 'Đã tiếp nhận'),
      ('processing', 'Đang giặt'),
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
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected ? darkBlue : const Color(0xFFDDE5EF),
            ),
            labelStyle: TextStyle(
              color: selected ? Colors.white : const Color(0xFF44546A),
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
      color: Colors.white,
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
                        child: Icon(order.statusIcon, color: order.statusColor, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Đơn #${order.id}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: darkBlue,
                            ),
                          ),
                          Text(
                            order.formattedCreatedAt,
                            style: const TextStyle(fontSize: 11, color: Colors.black54),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: order.statusColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      order.statusDisplayName,
                      style: TextStyle(
                        color: order.statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
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
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.phone, color: Colors.green, size: 20),
                    tooltip: 'Gọi điện',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                    onPressed: () => _makeCall(order.phone),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.directions, color: primaryBlue, size: 20),
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
                  const Icon(Icons.location_on_outlined, size: 16, color: Colors.blueGrey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      order.address,
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.blueGrey),
                  const SizedBox(width: 6),
                  Text(
                    'Lấy đồ: ${order.formattedPickupTime}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${order.items.length} món đồ',
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  Text(
                    order.formattedTotalPrice,
                    style: const TextStyle(
                      color: primaryBlue,
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
                          backgroundColor: primaryBlue,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: () => _quickUpdateStatus(order, 'confirmed', 'Đã tiếp nhận'),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Tiếp nhận'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      ),
                      onPressed: () => _quickUpdateStatus(order, 'cancelled', 'Đã hủy'),
                      child: const Text('Từ chối'),
                    ),
                  ],
                )
              else if (order.status == 'confirmed')
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7952B3),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () => _quickUpdateStatus(order, 'processing', 'Đang giặt sấy'),
                    icon: const Icon(Icons.local_laundry_service, size: 16),
                    label: const Text('Bắt đầu giặt sấy'),
                  ),
                )
              else if (order.status == 'processing')
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF16845B),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () => _quickUpdateStatus(order, 'completed', 'Đã hoàn tất'),
                    icon: const Icon(Icons.task_alt, size: 16),
                    label: const Text('Hoàn tất & Giao đồ'),
                  ),
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
      backgroundColor: const Color(0xFFF4F7FB),
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
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    const Text('Không tải được danh sách đơn toàn hệ thống.'),
                    const SizedBox(height: 6),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
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
                color: Colors.white,
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
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
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
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
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
