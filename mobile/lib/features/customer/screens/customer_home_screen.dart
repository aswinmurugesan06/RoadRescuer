import 'package:flutter/material.dart';
import '../../../routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/service_request_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/vehicle_service.dart';
import '../../../services/service_request_service.dart';
import '../../../widgets/rr_card.dart';
import '../../../widgets/vehicle_card_widget.dart';
import '../../../widgets/request_card_widget.dart';
import '../../../widgets/app_logo.dart';
import '../../vehicle/screens/my_vehicles_screen.dart';
import 'request_history_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  String _userName = 'User';
  List<VehicleModel> _vehicles = [];
  List<ServiceRequestModel> _recentRequests = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final name = await AuthService.getUserName();
      if (mounted && name != null && name.isNotEmpty) {
        setState(() => _userName = name);
      }

      final results = await Future.wait([
        VehicleService.getMyVehicles().catchError((_) => <VehicleModel>[]),
        ServiceRequestService.getMyRequests().catchError((_) => <ServiceRequestModel>[]),
      ]);

      if (mounted) {
        setState(() {
          _vehicles = results[0] as List<VehicleModel>;
          _recentRequests = results[1] as List<ServiceRequestModel>;
        });
      }
    } catch (_) {}
  }

  VehicleModel? get _defaultVehicle {
    if (_vehicles.isEmpty) return null;
    return _vehicles.firstWhere((v) => v.isDefault, orElse: () => _vehicles.first);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final defaultVehicle = _defaultVehicle;
    final firstName = _userName.trim().split(' ').first;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboardData,
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              // ── Header ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    AppLogo.appBar(
                                      height: 28,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'ROADRESCUE',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 2,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Hello, $firstName 👋',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Notification bell
                          GestureDetector(
                            onTap: () => Navigator.pushNamed(context, AppRoutes.notifications),
                            child: Stack(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.cardDark : AppColors.backgroundLight,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                                    ),
                                  ),
                                  child: const Icon(Icons.notifications_outlined, size: 22),
                                ),
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppColors.danger,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Avatar
                          GestureDetector(
                            onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor: AppColors.primary.withOpacity(0.15),
                              child: Text(
                                firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Selected vehicle card
                      if (defaultVehicle != null)
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppRoutes.vehicleDetails,
                            arguments: defaultVehicle,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: AppColors.primary.withOpacity(0.06),
                              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                Text(defaultVehicle.typeIcon, style: const TextStyle(fontSize: 28)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        defaultVehicle.displayName,
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        defaultVehicle.plateNumber,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.swap_horiz_rounded, color: textSecondary, size: 20),
                                const SizedBox(width: 4),
                                Text('Change', style: TextStyle(fontSize: 12, color: textSecondary)),
                              ],
                            ),
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: () async {
                            final added = await Navigator.pushNamed(context, AppRoutes.addVehicle);
                            if (added == true) _loadDashboardData();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: AppColors.primary.withOpacity(0.06),
                              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.add_rounded, color: AppColors.primary, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'No Vehicle Added Yet',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Add your vehicle to request fast assistance',
                                        style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.primary),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── SOS Button ──────────────────────────────────────
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, AppRoutes.requestAssistance),
                      child: Container(
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Color(0xFFE65100), Color(0xFFFF8C42)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.sos_rounded, size: 32, color: Colors.white),
                            SizedBox(width: 12),
                            Text(
                              'REQUEST ASSISTANCE',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Quick Services ──────────────────────────────────
                    const SectionHeader(title: 'Quick Services'),
                    const SizedBox(height: 14),
                    _buildQuickServices(context),

                    const SizedBox(height: 28),

                    // ── My Vehicles ──────────────────────────────────────
                    SectionHeader(
                      title: 'My Vehicles',
                      actionLabel: 'See All',
                      onAction: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MyVehiclesScreen()),
                      ).then((_) => _loadDashboardData()),
                    ),
                    const SizedBox(height: 14),
                    if (_vehicles.isNotEmpty)
                      ..._vehicles.take(2).map((v) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: VehicleCardWidget(
                              vehicle: v,
                              onTap: () => Navigator.pushNamed(
                                context,
                                AppRoutes.vehicleDetails,
                                arguments: v,
                              ).then((_) => _loadDashboardData()),
                              compact: true,
                            ),
                          ))
                    else
                      RRCard(
                        onTap: () async {
                          final added = await Navigator.pushNamed(context, AppRoutes.addVehicle);
                          if (added == true) _loadDashboardData();
                        },
                        child: Row(
                          children: const [
                            Icon(Icons.directions_car_outlined, color: AppColors.primary),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Tap to add your first vehicle',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                          ],
                        ),
                      ),

                    const SizedBox(height: 28),

                    // ── Recent Requests ──────────────────────────────────
                    SectionHeader(
                      title: 'Recent Requests',
                      actionLabel: 'See All',
                      onAction: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RequestHistoryScreen()),
                      ).then((_) => _loadDashboardData()),
                    ),
                    const SizedBox(height: 14),
                    if (_recentRequests.isNotEmpty)
                      ..._recentRequests.take(2).map((r) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: RequestCardWidget(
                              request: r,
                              onTap: () => Navigator.pushNamed(
                                context,
                                AppRoutes.activeAssistance,
                                arguments: {'request': r},
                              ).then((_) => _loadDashboardData()),
                            ),
                          ))
                    else
                      RRCard(
                        child: Row(
                          children: const [
                            Icon(Icons.history_rounded, color: AppColors.primary),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No recent assistance requests',
                                style: TextStyle(fontSize: 14, color: AppColors.textSecondaryLight),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickServices(BuildContext context) {
    final services = [
      {'label': 'Mechanic', 'icon': Icons.build_rounded, 'color': AppColors.mechanic, 'type': 'Mechanic'},
      {'label': 'Puncture', 'icon': Icons.tire_repair_rounded, 'color': AppColors.puncture, 'type': 'Puncture'},
      {'label': 'Tow', 'icon': Icons.local_shipping_rounded, 'color': AppColors.tow, 'type': 'Tow'},
      {'label': 'Battery', 'icon': Icons.battery_charging_full_rounded, 'color': AppColors.battery, 'type': 'Battery'},
      {'label': 'Fuel', 'icon': Icons.local_gas_station_rounded, 'color': AppColors.fuel, 'type': 'Fuel'},
    ];

    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: services.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final s = services[i];
          final color = s['color'] as Color;
          return GestureDetector(
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.selectProblem,
              arguments: {
                'serviceType': s['type'],
                'vehicle': _defaultVehicle,
              },
            ),
            child: Column(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withOpacity(0.2)),
                  ),
                  child: Icon(s['icon'] as IconData, color: color, size: 26),
                ),
                const SizedBox(height: 6),
                Text(
                  s['label'] as String,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
