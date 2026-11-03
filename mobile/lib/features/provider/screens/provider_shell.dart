import 'package:flutter/material.dart';
import 'provider_home_screen.dart';
import 'active_job_screen.dart';
import 'provider_history_screen.dart';
import 'provider_earnings_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../../widgets/glass.dart';

class ProviderShell extends StatefulWidget {
  const ProviderShell({super.key});

  @override
  State<ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends State<ProviderShell> {
  int _currentIndex = 0;

  static const List<GlassNavItem> _destinations = [
    GlassNavItem(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
      label: 'Dashboard',
    ),
    GlassNavItem(
      icon: Icons.engineering_outlined,
      selectedIcon: Icons.engineering_rounded,
      label: 'Active Job',
    ),
    GlassNavItem(
      icon: Icons.history_outlined,
      selectedIcon: Icons.history_rounded,
      label: 'History',
    ),
    GlassNavItem(
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet_rounded,
      label: 'Earnings',
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
      const ProviderHomeScreen(),
      const ActiveJobScreen(),
      const ProviderHistoryScreen(),
      const ProviderEarningsScreen(),
      const ProfileScreen(),
    ];
  }

  void _selectTab(int index) {
    setState(() {
      // Refresh data-backed tabs when they are opened so a job accepted on
      // another route is not shown again as "available".
      if (index == 0) {
        _pages[0] = const ProviderHomeScreen();
      } else if (index == 1) {
        _pages[1] = const ActiveJobScreen();
      }
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: GlassBottomNav(
        items: _destinations,
        currentIndex: _currentIndex,
        onTap: _selectTab,
      ),
    );
  }
}
