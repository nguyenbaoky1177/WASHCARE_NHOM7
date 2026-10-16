import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/supabase_client.dart';
import '../models/models.dart';
import 'order_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<ProfileModel?> _profileFuture;
  late Future<List<ServiceModel>> _servicesFuture;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  void _loadAll() {
    _profileFuture = _loadProfile();
    _servicesFuture = _loadServices();
  }

  Future<void> _refresh() async {
    setState(() {
      _loadAll();
    });
    try {
      await Future.wait([_profileFuture, _servicesFuture]);
    } catch (_) {
      // FutureBuilder will render the error state.
    }
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

  @override
  Widget build(BuildContext context) {
    final email = supabase.auth.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.local_laundry_service, size: 28),
            SizedBox(width: 10),
            Text(
              'WashCare',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: () async {
              await supabase.auth.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            FutureBuilder<ProfileModel?>(
              future: _profileFuture,
              builder: (context, snapshot) {
                final profile = snapshot.data;
                final name = (profile != null && profile.fullName.isNotEmpty)
                    ? profile.fullName
                    : 'Khách hàng';

                return Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [primaryBlue, Color(0xFF55A5F5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'XIN CHÀO!',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        email,
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Để WashCare chăm sóc quần áo của bạn!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 26),
            const Text(
              'Dịch vụ của chúng tôi',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: darkBlue,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Chọn dịch vụ phù hợp với nhu cầu của bạn.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                final placed = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OrderPage(),
                  ),
                );
                if (placed == true && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Đặt đơn thành công! Bạn có thể theo dõi tiến độ tại tab Đơn hàng.',
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Đặt dịch vụ ngay'),
              style: FilledButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<ServiceModel>>(
              future: _servicesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.cloud_off,
                          size: 40,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Không tải được danh sách dịch vụ.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        TextButton(
                          onPressed: _refresh,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  );
                }

                final services = snapshot.data ?? [];

                if (services.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Hiện chưa có dịch vụ nào.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return Column(
                  children: services.map((service) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFE4ECF5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: paleBlue,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              service.iconData,
                              size: 32,
                              color: primaryBlue,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  service.name,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: darkBlue,
                                  ),
                                ),
                                if (service.description.isNotEmpty) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    service.description,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Text(
                                  '${service.formattedPrice} đ / ${service.unit}',
                                  style: const TextStyle(
                                    color: primaryBlue,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: paleBlue,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    color: primaryBlue,
                    size: 34,
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quần áo sạch, cuộc sống nhẹ nhàng',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: darkBlue,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'WashCare luôn sẵn sàng phục vụ bạn.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
