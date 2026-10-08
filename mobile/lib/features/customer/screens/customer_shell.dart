import 'package:flutter/material.dart';
import 'customer_home_screen.dart';
import '../../vehicle/screens/my_vehicles_screen.dart';
import 'request_history_screen.dart';
import '../../profile/screens/profile_screen.dart';

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _currentIndex = 0;

  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.directions_car_outlined),
      selectedIcon: Icon(Icons.directions_car_rounded),
      label: 'Vehicles',
    ),
    NavigationDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long_rounded),
      label: 'Requests',
    ),
    NavigationDestination(
      icon: Icon(Icons.payment_outlined),
      selectedIcon: Icon(Icons.payment_rounded),
      label: 'Payments',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          destinations: _destinations,
          animationDuration: const Duration(milliseconds: 300),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
      ),
    );
  }
}
