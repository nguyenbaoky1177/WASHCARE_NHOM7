import '../../core/request_timeout.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/review_service.dart';
import '../../core/supabase_client.dart';
import '../../models/models.dart';
import 'admin_orders_page.dart';
import 'admin_services_page.dart';
import 'admin_users_page.dart';

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
          AdminUsersPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        backgroundColor: context.cardSurface,
        indicatorColor: context.accentSurface,
        elevation: 8,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics, color: context.headingColor),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: context.headingColor),
            label: 'Đơn hàng',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category, color: context.headingColor),
            label: 'Dịch vụ & Giá',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded, color: context.headingColor),
            label: 'Người dùng',
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
  double _csat = 0;
  int _reviewCount = 0;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadData();
    _loadCsat();
  }

  Future<void> _loadCsat() async {
    try {
      final avg = await ReviewService.getAverageRating();
      final count = await ReviewService.getReviewCount();
      if (mounted) {
        setState(() {
          _csat = avg;
          _reviewCount = count;
        });
      }
    } catch (_) {}
  }

  Future<List<OrderModel>> _loadData() async {
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
    final future = _loadData();
    setState(() => _dashboardFuture = future);
    _loadCsat();
    try {
      await future;
    } catch (_) {}
  }

  String _formatMoney(num val) {
    return val
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => '.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageSurface,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.dashboard_outlined, color: Colors.amber),
            SizedBox(width: 8),
            Text(
              'Dashboard Quản trị',
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
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Không tải được dữ liệu tổng quan.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _refresh,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          final orders = snapshot.data ?? [];

          final pendingOrders = orders
              .where((o) => o.status == 'pending')
              .toList();
          final confirmedOrders = orders
              .where((o) => o.status == 'confirmed')
              .toList();
          final washingOrders = orders
              .where((o) => o.status == 'washing')
              .toList();
          final deliveringOrders = orders
              .where((o) => o.status == 'delivering')
              .toList();
          final completedOrders = orders
              .where((o) => o.status == 'completed')
              .toList();

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
                          Icon(
                            Icons.account_balance_wallet,
                            color: Colors.amber,
                            size: 24,
                          ),
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
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // KPI Grid
                Text(
                  'Tình trạng vận hành',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.headingColor,
                  ),
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
                        count: washingOrders.length,
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
                const SizedBox(height: 14),

                _kpiCard(
                  title: 'Đang giao hàng',
                  count: deliveringOrders.length,
                  color: Colors.teal,
                  icon: Icons.local_shipping,
                ),
                const SizedBox(height: 14),

                // CSAT Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.cardSurface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: context.cardOutline),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.star_rounded,
                          color: Colors.amber,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Chỉ số hài lòng khách hàng (CSAT)',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: context.mutedColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  _reviewCount == 0
                                      ? 'Chưa có đánh giá'
                                      : '${_csat.toStringAsFixed(1)} / 5.0',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: context.headingColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$_reviewCount đánh giá',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Urgent Pending Orders Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Đơn hàng cần xử lý gấp',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.headingColor,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
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
                      color: context.cardSurface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: context.cardOutline),
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
                      color: context.cardSurface,
                      elevation: 0.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Color(0xFFE4ECF5)),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFED8B00)
                              .withValues(alpha: 0.12),
                          child: const Icon(
                            Icons.schedule,
                            color: Color(0xFFED8B00),
                          ),
                        ),
                        title: Text(
                          'Đơn #${o.id} • ${o.customerName}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Hẹn lấy: ${o.formattedPickupTime}\n${o.address}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          o.formattedTotalPrice,
                          style: const TextStyle(
                            color: primaryBlue,
                            fontWeight: FontWeight.bold,
                          ),
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
        color: context.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.cardOutline),
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
                style: TextStyle(fontSize: 12, color: context.mutedColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
