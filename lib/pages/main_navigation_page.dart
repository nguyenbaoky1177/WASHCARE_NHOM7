import 'package:flutter/material.dart';

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
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _loadedTabs.contains(0) ? const HomePage() : const SizedBox.shrink(),
          _loadedTabs.contains(1) ? const ActiveOrdersPage() : const SizedBox.shrink(),
          _loadedTabs.contains(2) ? const AccountPage() : const SizedBox.shrink(),
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
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFDCEBFA),
        elevation: 8,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Đơn hàng',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }
}
