import '../core/request_timeout.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_colors.dart';
import '../core/app_settings.dart';
import '../core/notification_service.dart';
import '../core/profile_cache.dart';
import '../core/service_cache.dart';
import '../core/supabase_client.dart';
import '../models/models.dart';
import 'customer_order_detail_page.dart';
import 'notifications_page.dart';
import 'order_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.isVisible = true});

  final bool isVisible;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<ProfileModel?> _profileFuture;
  late Future<List<ServiceModel>> _servicesFuture;
  late Future<OrderModel?> _activeOrderFuture;
  int _unreadNotificationCount = 0;

  final PageController _bannerController = PageController();
  int _currentBannerIndex = 0;
  Timer? _bannerTimer;

  final List<Map<String, dynamic>> _promoBanners = const [
    {
      'title': 'GIẢM 20.000đ ĐƠN ĐẦU TIÊN',
      'subtitle': 'Nhập mã: WASHCARE20 khi đặt đơn',
      'tag': 'ƯU ĐÃI MỚI',
      'titleEn': 'SAVE ₫20,000 ON YOUR FIRST ORDER',
      'subtitleEn': 'Use code WASHCARE20 at checkout',
      'tagEn': 'NEW OFFER',
      'icon': Icons.card_giftcard,
      'colors': [Color(0xFF17365D), Color(0xFF2878D0)],
    },
    {
      'title': 'MÙA MƯA KHÔNG LO ẨM MỐC',
      'subtitle': 'Sấy tiệt trùng nhiệt độ cao chỉ trong 2 giờ',
      'tag': 'SẤY KHÔ 2H',
      'titleEn': 'KEEP LAUNDRY DRY IN RAINY SEASON',
      'subtitleEn': 'High-temperature drying in just 2 hours',
      'tagEn': '2-HOUR DRYING',
      'icon': Icons.wb_sunny_outlined,
      'colors': [Color(0xFF0F766E), Color(0xFF14B8A6)],
    },
    {
      'title': 'CHĂM SÓC TRANG PHỤC CAO CẤP',
      'subtitle': 'Giặt hấp chuẩn tiệm cho Vest, Đầm dạ hội & Giày hiệu',
      'tag': 'CHUYÊN SÂU',
      'titleEn': 'EXPERT GARMENT CARE',
      'subtitleEn': 'Dry cleaning for suits, eveningwear and shoes',
      'tagEn': 'SPECIALIST CARE',
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
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) {
      _refresh();
    }
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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) {
      return AppSettings.text(context, 'Chào buổi sáng ☀️', 'Good morning ☀️');
    } else if (hour >= 11 && hour < 14) {
      return AppSettings.text(context, 'Chào buổi trưa 🌤️', 'Good afternoon 🌤️');
    } else if (hour >= 14 && hour < 18) {
      return AppSettings.text(context, 'Chào buổi chiều ⛅', 'Good afternoon ⛅');
    } else {
      return AppSettings.text(context, 'Chào buổi tối 🌙', 'Good evening 🌙');
    }
  }

  void _loadAll() {
    _profileFuture = _loadProfile();
    _servicesFuture = _loadServices();
    _activeOrderFuture = _loadLatestActiveOrder();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    final count = await NotificationService.getUnreadCount();
    if (mounted) {
      setState(() => _unreadNotificationCount = count);
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
    if (mounted) {
      _loadUnreadCount();
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _profileFuture = _loadProfile(forceNetwork: true);
      _servicesFuture = _loadServices(forceNetwork: true);
      _activeOrderFuture = _loadLatestActiveOrder();
      _loadUnreadCount();
    });
    try {
      await Future.wait([_profileFuture, _servicesFuture, _activeOrderFuture]);
    } catch (_) {}
  }

  Future<ProfileModel?> _loadProfile({bool forceNetwork = false}) async {
    return await ProfileCache.getProfile(forceNetwork: forceNetwork);
  }

  Future<List<ServiceModel>> _loadServices({bool forceNetwork = false}) async {
    return await ServiceCache.getServices(forceNetwork: forceNetwork);
  }

  Future<OrderModel?> _loadLatestActiveOrder() async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await supabase
          .from('orders')
          .select('*, order_items(*, services(name, unit))')
          .eq('user_id', user.id)
          .inFilter('status', ['pending', 'confirmed', 'washing', 'delivering'])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle()
          .timeout(supabaseRequestTimeout);

      if (response == null) return null;
      return OrderModel.fromJson(response);
    } catch (e) {
      debugPrint('HomePage._loadLatestActiveOrder error: $e');
      rethrow;
    }
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
      backgroundColor: context.pageSurface,
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
                  if (snapshot.hasError) {
                    return ListTile(
                      title: const Text('Chưa tải được đơn đang xử lý.'),
                      subtitle: const Text('Kiểm tra kết nối và thử lại.'),
                      trailing: TextButton(onPressed: _refresh, child: const Text('Thử lại')),
                    );
                  }
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        Text(
                          AppSettings.text(context, 'Dịch vụ giặt ủi', 'Laundry services'),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppSettings.text(context, 'Bảng giá niêm yết, chăm sóc tận tâm', 'Upfront pricing and careful service'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () async {
                        final placed = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(builder: (_) => const OrderPage()),
                        );
                        if (placed == true && context.mounted) {
                          _refresh();
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: primaryBlue, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(AppSettings.text(context, 'Đặt đơn', 'Book now')),
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
      color: context.cardSurface,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.accentSurface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.local_laundry_service,
              color: context.accentColor,
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getGreeting(),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: context.headingColor,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Thông báo',
                onPressed: _openNotifications,
                icon: Icon(
                  Icons.notifications_none_rounded,
                  color: context.accentColor,
                ),
              ),
              if (_unreadNotificationCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _unreadNotificationCount > 9 ? '9+' : '$_unreadNotificationCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: 'Hỗ trợ khách hàng',
            onPressed: _callHotline,
            icon: Icon(Icons.headset_mic_outlined, color: context.accentColor),
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
        color: context.cardSurface,
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
                  style: TextStyle(fontSize: 12, color: context.mutedColor),
                ),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: context.accentColor,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CustomerOrderDetailPage(order: order),
                ),
              );
              _refresh();
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppSettings.text(context, 'Theo dõi', 'Track order'),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
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
          height: 165 + (MediaQuery.textScalerOf(context).scale(16) - 16)
              .clamp(0.0, double.infinity) * 6,
          child: PageView.builder(
            controller: _bannerController,
            itemCount: _promoBanners.length,
            onPageChanged: (index) {
              setState(() => _currentBannerIndex = index);
            },
            itemBuilder: (context, index) {
              final b = _promoBanners[index];
              final colors = b['colors'] as List<Color>;
              String label(String key) => AppSettings.text(
                context, b[key] as String, b['${key}En'] as String,
              );

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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              label('tag'),
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
                            label('title'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            label('subtitle'),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      b['icon'] as IconData,
                      size: 48,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
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
      (AppSettings.text(context, 'Giặt sấy', 'Wash & dry'), Icons.local_laundry_service, paleBlue, primaryBlue),
      (
        AppSettings.text(context, 'Giặt hấp', 'Dry cleaning'),
        Icons.dry_cleaning,
        const Color(0xFFF3E8FF),
        const Color(0xFF9333EA),
      ),
      (AppSettings.text(context, 'Ủi / Là', 'Ironing'), Icons.iron, const Color(0xFFFEF3C7), const Color(0xFFD97706)),
      (
        AppSettings.text(context, 'Vệ sinh giày', 'Shoe care'),
        Icons.directions_walk,
        const Color(0xFFDCFCE7),
        const Color(0xFF16A34A),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: categories.map((c) {
          final iconColor = context.isDarkTheme
              ? Color.lerp(c.$4, Colors.white, 0.38)!
              : c.$4;
          return Expanded(child: InkWell(
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
                    color: context.isDarkTheme
                        ? Color.alphaBlend(
                            iconColor.withValues(alpha: 0.15),
                            context.cardSurface,
                          )
                        : c.$3,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(c.$2, color: iconColor, size: 28),
                ),
                const SizedBox(height: 6),
                Text(
                  c.$1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.headingColor,
                  ),
                ),
              ],
            ),
          ));
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
            child: Column(
              children: [
                const Text('Không tải được dịch vụ. Vui lòng kiểm tra kết nối.'),
                TextButton(onPressed: _refresh, child: const Text('Thử lại')),
              ],
            ),
          );
        }

        final services = snapshot.data ?? [];
        if (services.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(18),
            child: Text('Cửa hàng hiện chưa có dịch vụ đang hoạt động.'),
          );
        }


        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            children: services.map((service) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.cardSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: context.cardOutline),
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
                        color: context.accentSurface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        service.iconData,
                        size: 28,
                        color: context.accentColor,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: context.headingColor,
                            ),
                          ),
                          if (service.description.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              service.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.mutedColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            '${service.formattedPrice} đ / ${service.unit}',
                            style: TextStyle(
                              color: context.accentColor,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.add_circle,
                        color: context.accentColor,
                        size: 30,
                      ),
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
      (
        'Giặt riêng từng mẻ',
        'Không trộn lẫn quần áo của khách khác',
        Icons.verified_user_outlined,
      ),
      (
        'Nước giặt sinh học',
        'An toàn tuyệt đối cho da nhạy cảm & em bé',
        Icons.eco_outlined,
      ),
      (
        'Giao nhận 2 giờ',
        'Đúng giờ hẹn, shipper thân thiện chu đáo',
        Icons.timer_outlined,
      ),
      (
        'Bảo hiểm trang phục',
        'Đền bù 100% nếu xảy ra hư hao thất lạc',
        Icons.shield_outlined,
      ),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.cardOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium, color: Colors.amber, size: 22),
              SizedBox(width: 8),
              Text(
                '4 Cam kết vàng từ WashCare',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: context.headingColor,
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
                  Icon(c.$3, size: 20, color: context.accentColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.$1,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: context.headingColor,
                          ),
                        ),
                        Text(
                          c.$2,
                          style: TextStyle(
                            fontSize: 11,
                            color: context.mutedColor,
                          ),
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
        color: context.accentSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD6E8FB)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.cardSurface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.phone_in_talk,
              color: context.accentColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tổng đài hỗ trợ 24/7',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: context.headingColor,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Hotline: 1900 1234 (Miễn phí cuộc gọi)',
                  style: TextStyle(fontSize: 12, color: context.mutedColor),
                ),
              ],
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: context.accentColor,
              side: BorderSide(color: context.accentColor),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _callHotline,
            child: const Text(
              'Gọi ngay',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
