
import 'package:flutter/material.dart';

import 'account_page.dart';
import 'home_page.dart';
import 'active_orders_page.dart';

class MainNavigationPage extends StatefulWidget {
const MainNavigationPage({super.key});

@override
State<MainNavigationPage> createState() =>
_MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
int _selectedIndex = 0;

final List<Widget> _pages = const [
HomePage(),
ActiveOrdersPage(),
AccountPage(),
];

@override
Widget build(BuildContext context) {
return Scaffold(
body: IndexedStack(
index: _selectedIndex,
children: _pages,
),
bottomNavigationBar: NavigationBar(
selectedIndex: _selectedIndex,
onDestinationSelected: (index) {
setState(() {
_selectedIndex = index;
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
