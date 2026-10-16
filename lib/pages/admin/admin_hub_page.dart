import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/supabase_client.dart';
import '../../models/models.dart';
import 'admin_orders_page.dart';
import 'admin_services_page.dart';

class AdminHubPage extends StatefulWidget {
  const AdminHubPage({super.key});

  @override
  State<AdminHubPage> createState() => _AdminHubPageState();
}

class _AdminHubPageState extends State<AdminHubPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          AdminDashboardView(),
          AdminOrdersPage(),
          AdminServicesPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFDCEBFA),
        elevation: 8,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics, color: darkBlue),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: darkBlue),
            label: 'Đơn hàng',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category, color: darkBlue),
            label: 'Dịch vụ & Giá',
          ),
        ],
      ),
    );
  }
}

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  late Future<List<OrderModel>> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadData();
  }

  Future<List<OrderModel>> _loadData() async {
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
    final future = _loadData();
    setState(() => _dashboardFuture = future);
    try {
      await future;
    } catch (_) {}
  }

  String _formatMoney(num val) {
    return val.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.dashboard_outlined, color: Colors.amber),
            SizedBox(width: 8),
            Text('Dashboard Quản trị', style: TextStyle(fontWeight: FontWeight.bold)),
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
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data ?? [];

          final pendingOrders = orders.where((o) => o.status == 'pending').toList();
          final confirmedOrders = orders.where((o) => o.status == 'confirmed').toList();
          final processingOrders = orders.where((o) => o.status == 'processing').toList();
          final completedOrders = orders.where((o) => o.status == 'completed').toList();

          double totalRevenue = 0;
          for (final o in completedOrders) {
            totalRevenue += o.totalPrice;
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Revenue Hero Card
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF17365D), Color(0xFF2878D0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF17365D).withValues(alpha: 0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.account_balance_wallet, color: Colors.amber, size: 24),
                          SizedBox(width: 8),
                          Text(
                            'TỔNG DOANH THU ĐƠN HOÀN TẤT',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${_formatMoney(totalRevenue)} đ',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Từ ${completedOrders.length} đơn hàng đã giao thành công',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // KPI Grid
                const Text(
                  'Tình trạng vận hành',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _kpiCard(
                        title: 'Chờ duyệt',
                        count: pendingOrders.length,
                        color: const Color(0xFFED8B00),
                        icon: Icons.hourglass_top,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _kpiCard(
                        title: 'Đã tiếp nhận',
                        count: confirmedOrders.length,
                        color: primaryBlue,
                        icon: Icons.check_circle_outline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _kpiCard(
                        title: 'Đang giặt sấy',
                        count: processingOrders.length,
                        color: const Color(0xFF7952B3),
                        icon: Icons.local_laundry_service,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _kpiCard(
                        title: 'Đã hoàn thành',
                        count: completedOrders.length,
                        color: const Color(0xFF16845B),
                        icon: Icons.task_alt,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Urgent Pending Orders Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Đơn hàng cần xử lý gấp',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkBlue),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: pendingOrders.isNotEmpty
                            ? Colors.red.withValues(alpha: 0.12)
                            : Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${pendingOrders.length} đơn',
                        style: TextStyle(
                          color: pendingOrders.isNotEmpty ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (pendingOrders.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE4ECF5)),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.check_circle, size: 48, color: Colors.green),
                        SizedBox(height: 10),
                        Text(
                          'Tuyệt vời! Không có đơn nào đang chờ duyệt.',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )
                else
                  ...pendingOrders.take(3).map((o) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      color: Colors.white,
                      elevation: 0.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Color(0xFFE4ECF5)),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFED8B00).withValues(alpha: 0.12),
                          child: const Icon(Icons.schedule, color: Color(0xFFED8B00)),
                        ),
                        title: Text('Đơn #${o.id} • ${o.customerName}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Hẹn lấy: ${o.formattedPickupTime}\n${o.address}',
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: Text(
                          o.formattedTotalPrice,
                          style: const TextStyle(
                              color: primaryBlue, fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _kpiCard({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4ECF5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
