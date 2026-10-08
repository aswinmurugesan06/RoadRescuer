import 'package:flutter/material.dart';
import 'provider_home_screen.dart';
import 'active_job_screen.dart';
import 'provider_history_screen.dart';
import 'provider_earnings_screen.dart';
import '../../profile/screens/profile_screen.dart';

class ProviderShell extends StatefulWidget {
  const ProviderShell({super.key});

  @override
  State<ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends State<ProviderShell> {
  int _currentIndex = 0;

  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard_rounded),
      label: 'Dashboard',
    ),
    NavigationDestination(
      icon: Icon(Icons.engineering_outlined),
      selectedIcon: Icon(Icons.engineering_rounded),
      label: 'Active Job',
    ),
    NavigationDestination(
      icon: Icon(Icons.history_outlined),
      selectedIcon: Icon(Icons.history_rounded),
      label: 'History',
    ),
    NavigationDestination(
      icon: Icon(Icons.account_balance_wallet_outlined),
      selectedIcon: Icon(Icons.account_balance_wallet_rounded),
      label: 'Earnings',
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
      const ProviderHomeScreen(),
      const ActiveJobScreen(),
      const ProviderHistoryScreen(),
      const ProviderEarningsScreen(),
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
