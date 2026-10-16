import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_colors.dart';
import '../core/supabase_client.dart';
import '../models/models.dart';
import 'active_orders_page.dart';
import 'order_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<ProfileModel?> _profileFuture;
  late Future<List<ServiceModel>> _servicesFuture;
  late Future<OrderModel?> _activeOrderFuture;

  final PageController _bannerController = PageController();
  int _currentBannerIndex = 0;
  Timer? _bannerTimer;

  final List<Map<String, dynamic>> _promoBanners = const [
    {
      'title': 'GIẢM 20.000đ ĐƠN ĐẦU TIÊN',
      'subtitle': 'Nhập mã: WASHCARE20 khi đặt đơn',
      'tag': 'ƯU ĐÃI MỚI',
      'icon': Icons.card_giftcard,
      'colors': [Color(0xFF17365D), Color(0xFF2878D0)],
    },
    {
      'title': 'MÙA MƯA KHÔNG LO ẨM MỐC',
      'subtitle': 'Sấy tiệt trùng nhiệt độ cao chỉ trong 2 giờ',
      'tag': 'SẤY KHÔ 2H',
      'icon': Icons.wb_sunny_outlined,
      'colors': [Color(0xFF0F766E), Color(0xFF14B8A6)],
    },
    {
      'title': 'CHĂM SÓC TRANG PHỤC CAO CẤP',
      'subtitle': 'Giặt hấp chuẩn tiệm cho Vest, Đầm dạ hội & Giày hiệu',
      'tag': 'CHUYÊN SÂU',
      'icon': Icons.dry_cleaning,
      'colors': [Color(0xFF581C87), Color(0xFF9333EA)],
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadAll();
    _startBannerAutoScroll();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  void _startBannerAutoScroll() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_bannerController.hasClients) {
        final nextPage = (_currentBannerIndex + 1) % _promoBanners.length;
        _bannerController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _loadAll() {
    _profileFuture = _loadProfile();
    _servicesFuture = _loadServices();
    _activeOrderFuture = _loadLatestActiveOrder();
  }

  Future<void> _refresh() async {
    setState(() {
      _loadAll();
    });
    try {
      await Future.wait([_profileFuture, _servicesFuture, _activeOrderFuture]);
    } catch (_) {}
  }

  Future<ProfileModel?> _loadProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    final response = await supabase
        .from('profiles')
        .select('id, full_name, phone, role, created_at')
        .eq('id', user.id)
        .maybeSingle();

    if (response == null) return null;
    return ProfileModel.fromJson(response);
  }

  Future<List<ServiceModel>> _loadServices() async {
    final response = await supabase
        .from('services')
        .select('id, name, description, price, unit, icon, is_active')
        .eq('is_active', true)
        .order('id');

    return (response as List)
        .whereType<Map<String, dynamic>>()
        .map((e) => ServiceModel.fromJson(e))
        .toList();
  }

  Future<OrderModel?> _loadLatestActiveOrder() async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    final response = await supabase
        .from('orders')
        .select('*, order_items(*, services(name, unit))')
        .eq('user_id', user.id)
        .inFilter('status', ['pending', 'confirmed', 'processing'])
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return OrderModel.fromJson(response);
  }

  Future<void> _callHotline() async {
    final uri = Uri.parse('tel:19001234');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // 1. Top Header Bar with Location & User Info
              _buildTopHeader(),

              // 2. Active Order Live Tracking Banner (if any)
              FutureBuilder<OrderModel?>(
                future: _activeOrderFuture,
                builder: (context, snapshot) {
                  final activeOrder = snapshot.data;
                  if (activeOrder == null) return const SizedBox.shrink();
                  return _buildActiveOrderLivePill(activeOrder);
                },
              ),

              // 3. Promo Banner Carousel
              _buildPromoCarousel(),

              // 4. Quick Category Icons Grid
              _buildCategoryShortcuts(),

              const SizedBox(height: 12),

              // 5. Services Section Header & Quick Booking Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dịch vụ giặt ủi',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: darkBlue,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Bảng giá niêm yết, chăm sóc tận tâm',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      onPressed: () async {
                        final placed = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const OrderPage(),
                          ),
                        );
                        if (placed == true && context.mounted) {
                          _refresh();
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: primaryBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Đặt đơn'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 6. Services List Cards
              _buildServicesList(),

              const SizedBox(height: 20),

              // 7. 4 Golden Commitments (Real-world brand value)
              _buildQualityCommitments(),

              const SizedBox(height: 20),

              // 8. 24/7 Hotline Support Card
              _buildHotlineCard(),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: paleBlue,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.local_laundry_service,
              color: primaryBlue,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FutureBuilder<ProfileModel?>(
              future: _profileFuture,
              builder: (context, snapshot) {
                final name = snapshot.data?.fullName.isNotEmpty == true
                    ? snapshot.data!.fullName
                    : 'Khách hàng';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 13, color: primaryBlue),
                        const SizedBox(width: 3),
                        const Text(
                          'Giao nhận tận nơi',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Xin chào, $name!',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: darkBlue,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          IconButton(
            tooltip: 'Hỗ trợ khách hàng',
            onPressed: _callHotline,
            icon: const Icon(Icons.headset_mic_outlined, color: primaryBlue),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveOrderLivePill(OrderModel order) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 14, 18, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: order.statusColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: order.statusColor.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: order.statusColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(order.statusIcon, color: order.statusColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: order.statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Đơn #${order.id} • ${order.statusDisplayName}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: order.statusColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Hẹn lấy: ${order.formattedPickupTime}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: primaryBlue,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderDetailPage(
                    order: order,
                    onCancel: () async {},
                  ),
                ),
              );
              _refresh();
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Theo dõi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Icon(Icons.chevron_right, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoCarousel() {
    return Column(
      children: [
        SizedBox(
          height: 140,
          child: PageView.builder(
            controller: _bannerController,
            itemCount: _promoBanners.length,
            onPageChanged: (index) {
              setState(() => _currentBannerIndex = index);
            },
            itemBuilder: (context, index) {
              final b = _promoBanners[index];
              final colors = b['colors'] as List<Color>;

              return Container(
                margin: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: colors.first.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              b['tag'].toString(),
                              style: const TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            b['title'].toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            b['subtitle'].toString(),
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Icon(b['icon'] as IconData, size: 48, color: Colors.white.withValues(alpha: 0.3)),
                  ],
                ),
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_promoBanners.length, (i) {
            final active = i == _currentBannerIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? primaryBlue : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildCategoryShortcuts() {
    final categories = [
      ('Giặt sấy', Icons.local_laundry_service, paleBlue, primaryBlue),
      ('Giặt hấp', Icons.dry_cleaning, const Color(0xFFF3E8FF), const Color(0xFF9333EA)),
      ('Ủi / Là', Icons.iron, const Color(0xFFFEF3C7), const Color(0xFFD97706)),
      ('Vệ sinh giày', Icons.directions_walk, const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: categories.map((c) {
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OrderPage()),
              );
            },
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: c.$3,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(c.$2, color: c.$4, size: 28),
                ),
                const SizedBox(height: 6),
                Text(
                  c.$1,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: darkBlue),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildServicesList() {
    return FutureBuilder<List<ServiceModel>>(
      future: _servicesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(18),
            child: Text('Lỗi tải dịch vụ: ${snapshot.error}', textAlign: TextAlign.center),
          );
        }

        final services = snapshot.data ?? [];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            children: services.map((service) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE4ECF5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: paleBlue,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(service.iconData, size: 28, color: primaryBlue),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: darkBlue,
                            ),
                          ),
                          if (service.description.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              service.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            '${service.formattedPrice} đ / ${service.unit}',
                            style: const TextStyle(
                              color: primaryBlue,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: primaryBlue, size: 30),
                      tooltip: 'Đặt ngay',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const OrderPage()),
                        );
                      },
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildQualityCommitments() {
    final commitments = [
      ('Giặt riêng từng mẻ', 'Không trộn lẫn quần áo của khách khác', Icons.verified_user_outlined),
      ('Nước giặt sinh học', 'An toàn tuyệt đối cho da nhạy cảm & em bé', Icons.eco_outlined),
      ('Giao nhận 2 giờ', 'Đúng giờ hẹn, shipper thân thiện chu đáo', Icons.timer_outlined),
      ('Bảo hiểm trang phục', 'Đền bù 100% nếu xảy ra hư hao thất lạc', Icons.shield_outlined),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4ECF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.workspace_premium, color: Colors.amber, size: 22),
              SizedBox(width: 8),
              Text(
                '4 Cam kết vàng từ WashCare',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: darkBlue,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          ...commitments.map((c) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(c.$3, size: 20, color: primaryBlue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.$1,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: darkBlue),
                        ),
                        Text(
                          c.$2,
                          style: const TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHotlineCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: paleBlue,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD6E8FB)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.phone_in_talk, color: primaryBlue, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tổng đài hỗ trợ 24/7',
                  style: TextStyle(fontWeight: FontWeight.bold, color: darkBlue, fontSize: 14),
                ),
                SizedBox(height: 2),
                Text('Hotline: 1900 1234 (Miễn phí cuộc gọi)',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryBlue,
              side: const BorderSide(color: primaryBlue),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _callHotline,
            child: const Text('Gọi ngay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
