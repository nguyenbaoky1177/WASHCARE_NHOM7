import 'package:flutter/material.dart';

import '../core/app_settings.dart';
import 'account_page.dart';
import 'active_orders_page.dart';
import 'home_page.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _selectedIndex = 0;
  // Khởi tạo lười (lazy load): Chỉ khởi chạy tab khi người dùng truy cập
  // Giúp khởi động ứng dụng tức thì mà không bị nghẽn mạng
  final Set<int> _loadedTabs = {0};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _loadedTabs.contains(0)
              ? HomePage(isVisible: _selectedIndex == 0)
              : const SizedBox.shrink(),
          _loadedTabs.contains(1)
              ? ActiveOrdersPage(isVisible: _selectedIndex == 1)
              : const SizedBox.shrink(),
          _loadedTabs.contains(2)
              ? const AccountPage()
              : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
            _loadedTabs.add(index);
          });
        },
        backgroundColor: dark
            ? theme.colorScheme.surfaceContainer
            : Colors.white,
        indicatorColor: dark
            ? theme.colorScheme.secondaryContainer
            : const Color(0xFFDCEBFA),
        elevation: 8,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: AppSettings.text(context, 'Trang chủ', 'Home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long),
            label: AppSettings.text(context, 'Đơn hàng', 'Orders'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: AppSettings.text(context, 'Tài khoản', 'Account'),
          ),
        ],
      ),
    );
  }
}
