import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_colors.dart';
import '../core/supabase_client.dart';
import 'order_page.dart';
import 'order_history_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<Map<String, dynamic>?> loadProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    return await supabase
        .from('profiles')
        .select('full_name, role')
        .eq('id', user.id)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> loadServices() async {
    final response = await supabase
        .from('services')
        .select('id, name, description, price, unit, icon')
        .eq('is_active', true)
        .order('id');

    return List<Map<String, dynamic>>.from(response);
  }

  IconData _serviceIcon(String? name) {
    switch (name) {
      case 'local_laundry_service':
        return Icons.local_laundry_service;
      case 'iron':
        return Icons.iron;
      case 'dry_cleaning':
        return Icons.dry_cleaning;
      case 'checkroom':
        return Icons.checkroom;
      case 'steps':
        return Icons.directions_walk;
      default:
        return Icons.local_laundry_service;
    }
  }

  String _formatPrice(dynamic value) {
    final price = double.tryParse(value.toString()) ?? 0;
    return price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => '.',
    );
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
        onRefresh: () async {
          // Kéo xuống để tải lại danh sách dịch vụ.
          // FutureBuilder bên dưới sẽ được làm mới khi mở lại trang.
          await loadServices();
        },
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            FutureBuilder<Map<String, dynamic>?>(
              future: loadProfile(),
              builder: (context, snapshot) {
                final name =
                    snapshot.data?['full_name']?.toString() ??
                        'Khách hàng';

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
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OrderPage(),
                  ),
                );
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

            FutureBuilder<List<Map<String, dynamic>>>(
              future: loadServices(),
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
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const HomePage(),
                              ),
                            );
                          },
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
                    final name =
                        service['name']?.toString() ?? 'Dịch vụ';
                    final description =
                        service['description']?.toString() ?? '';
                    final unit = service['unit']?.toString() ?? '';
                    final iconName = service['icon']?.toString();
                    final price = _formatPrice(service['price']);

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
                              _serviceIcon(iconName),
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
                                  name,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: darkBlue,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  description,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '$price đ / $unit',
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
