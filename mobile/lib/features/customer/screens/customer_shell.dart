import 'package:flutter/material.dart';
import 'customer_home_screen.dart';
import '../../vehicle/screens/my_vehicles_screen.dart';
import 'request_history_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../../widgets/glass.dart';

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _currentIndex = 0;

  static const List<GlassNavItem> _destinations = [
    GlassNavItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Home',
    ),
    GlassNavItem(
      icon: Icons.directions_car_outlined,
      selectedIcon: Icons.directions_car_rounded,
      label: 'Vehicles',
    ),
    GlassNavItem(
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
      label: 'Requests',
    ),
    GlassNavItem(
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet_rounded,
      label: 'Payments',
    ),
    GlassNavItem(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const CustomerHomeScreen(),
      const MyVehiclesScreen(),
      const RequestHistoryScreen(),
      const CustomerPaymentHistoryScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: GlassBottomNav(
        items: _destinations,
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}
