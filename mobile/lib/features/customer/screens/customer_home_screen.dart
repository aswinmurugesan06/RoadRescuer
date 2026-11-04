import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/service_request_model.dart';
import '../../../models/vehicle_model.dart';
import '../../../routes/app_routes.dart';
import '../../../services/auth_service.dart';
import '../../../services/service_request_service.dart';
import '../../../services/vehicle_service.dart';
import '../../../widgets/app_logo.dart';
import '../../../widgets/glass.dart';
import '../../vehicle/screens/my_vehicles_screen.dart';
import 'request_history_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  String _userName = 'there';
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
        ServiceRequestService.getMyRequests()
            .catchError((_) => <ServiceRequestModel>[]),
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
    return _vehicles.firstWhere(
      (vehicle) => vehicle.isDefault,
      orElse: () => _vehicles.first,
    );
  }

  ServiceRequestModel? _pickActiveRequest() {
    for (final request in _recentRequests) {
      if (request.status == RequestStatus.accepted ||
          request.status == RequestStatus.arriving ||
          request.status == RequestStatus.inService ||
          request.status == RequestStatus.active ||
          request.status == RequestStatus.pending ||
          request.status == RequestStatus.searching) {
        return request;
      }
    }
    return _recentRequests.isNotEmpty ? _recentRequests.first : null;
  }

  String get _firstName {
    final trimmed = _userName.trim();
    if (trimmed.isEmpty) return 'there';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  void _openService(String serviceType) {
    Navigator.pushNamed(
      context,
      AppRoutes.selectProblem,
      arguments: {
        'serviceType': serviceType,
        'vehicle': _defaultVehicle,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultVehicle = _defaultVehicle;
    final activeRequest = _pickActiveRequest();

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: GlassBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _loadDashboardData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(isDark),
                  const SizedBox(height: 18),
                  _buildGuardianHeader(isDark),
                  const SizedBox(height: 14),
                  _buildVehicleCard(isDark, defaultVehicle),
                  const SizedBox(height: 14),
                  _buildEmergencyHero(isDark),
                  const SizedBox(height: 22),
                  const GlassSectionHeading(
                    title: 'Emergency Services',
                    subtitle: 'Verified help at your roadside in minutes',
                  ),
                  const SizedBox(height: 10),
                  _buildServiceList(),
                  const SizedBox(height: 12),
                  _buildCostEstimatorCard(isDark, defaultVehicle),
                  const SizedBox(height: 22),
                  _buildNearbyPatrol(isDark),
                  const SizedBox(height: 14),
                  _buildResponderCard(isDark),
                  const SizedBox(height: 14),
                  _buildRecentProtection(isDark, activeRequest),
                  const SizedBox(height: 14),
                  _buildSafetyCard(isDark),
                  const SizedBox(height: 18),
                  _buildFooter(isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final secondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    return Row(
      children: [
        const AppLogo.appBar(height: 30),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RoadRescue',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
            Text(
              'Home',
              style: TextStyle(fontSize: 11, color: secondary),
            ),
          ],
        ),
        const Spacer(),
        _iconButton(
          icon: Icons.notifications_none_rounded,
          onTap: () => Navigator.pushNamed(context, AppRoutes.notifications),
          hasDot: true,
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white,
              ),
            ),
            child: Center(
              child: Text(
                _firstName.isNotEmpty ? _firstName[0].toUpperCase() : 'R',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _iconButton({
    required IconData icon,
    required VoidCallback onTap,
    bool hasDot = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white,
              ),
            ),
            child: Icon(icon, size: 21),
          ),
          if (hasDot)
            Positioned(
              right: 9,
              top: 9,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGuardianHeader(bool isDark) {
    final secondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.tertiary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.tertiary.withValues(alpha: 0.35),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'ROADRESCUE GUARDIAN • LIVE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.9,
                color: AppColors.tertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Hello $_firstName, you’re protected on the road',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 24,
            height: 1.15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 10),
        GlassPill(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  size: 17, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'GPS ready • breakdown help within 15 minutes',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : AppColors.textPrimaryLight,
                  ),
                ),
              ),
              Icon(Icons.signal_cellular_alt_rounded,
                  size: 14, color: secondary),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleCard(bool isDark, VehicleModel? vehicle) {
    final secondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    return GlassCard(
      onTap: vehicle == null
          ? () async {
              final added =
                  await Navigator.pushNamed(context, AppRoutes.addVehicle);
              if (added == true) _loadDashboardData();
            }
          : () => Navigator.pushNamed(
                context,
                AppRoutes.vehicleDetails,
                arguments: vehicle,
              ),
      child: Column(
        children: [
          Row(
            children: [
              GlassIconBox(
                icon: vehicle == null
                    ? Icons.add_rounded
                    : _vehicleIcon(vehicle.type),
                size: 48,
                iconSize: 26,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            vehicle?.displayName ?? 'Add your vehicle',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                        ),
                        if (vehicle?.year != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(${vehicle!.year})',
                            style: TextStyle(fontSize: 11, color: secondary),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        if (vehicle != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.white.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.white,
                              ),
                            ),
                            child: Text(
                              vehicle.plateNumber,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: isDark
                                    ? Colors.white70
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                          ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Covered',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () async {
                  if (vehicle == null) {
                    await Navigator.pushNamed(context, AppRoutes.addVehicle);
                  } else {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MyVehiclesScreen(),
                      ),
                    );
                  }
                  _loadDashboardData();
                },
                child: const Text('Switch'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : AppColors.dividerLight.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statTile(
                'VEHICLES',
                '${_vehicles.length} saved',
                AppColors.primary,
                isDark,
              ),
              _statTile(
                'REQUESTS',
                '${_recentRequests.length} total',
                AppColors.tertiary,
                isDark,
              ),
              _statTile(
                'COVERAGE',
                '24/7 active',
                AppColors.secondary,
                isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, Color color, bool isDark) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.white.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: isDark ? Colors.white38 : AppColors.textHintLight,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyHero(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.16),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: GlassCard(
        borderColor: AppColors.secondary.withValues(alpha: 0.28),
        color: isDark
            ? AppColors.cardDark.withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.84),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const GlassIconBox(
                  icon: Icons.sos_rounded,
                  color: AppColors.secondary,
                  size: 38,
                  iconSize: 20,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Need immediate help?',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.secondary.withValues(alpha: 0.18),
                    ),
                  ),
                  child: const Text(
                    'PRIORITY',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              'Stranded, flat tyre, battery or mechanical issue? Share your live GPS and get the nearest verified technician dispatched.',
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 11),
            GlassPill(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded,
                      size: 17, color: AppColors.secondary),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Nearest verified technician • ~6 mins away',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white70
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                  Text(
                    '3 standby',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GradientActionButton(
              label: 'Request Instant Assistance',
              icon: Icons.crisis_alert_rounded,
              colors: const [Color(0xFFF97316), Color(0xFFF43F5E)],
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.requestAssistance),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.verified_user_rounded,
                    size: 13, color: AppColors.tertiary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Verified responders • transparent pricing',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceList() {
    final services = [
      const _ServiceItem(
        title: 'Flat Tyre / Puncture',
        subtitle: 'Fast mobile repair and spare swap at roadside',
        icon: Icons.tire_repair_rounded,
        color: AppColors.mechanic,
        badge: 'Fastest',
        type: 'Puncture',
      ),
      const _ServiceItem(
        title: 'Battery Jump-Start',
        subtitle: '12V boost, battery test and terminal check',
        icon: Icons.electric_bolt_rounded,
        color: AppColors.battery,
        type: 'Battery',
      ),
      const _ServiceItem(
        title: 'Towing Service',
        subtitle: 'Flatbed transport for low-clearance and AWD vehicles',
        icon: Icons.fire_truck_rounded,
        color: AppColors.tow,
        badge: 'Flatbed',
        type: 'Tow',
      ),
      const _ServiceItem(
        title: 'Mechanic Breakdown',
        subtitle: 'On-site diagnostics, belts and emergency triage',
        icon: Icons.car_repair_rounded,
        color: AppColors.secondary,
        type: 'Mechanic',
      ),
      const _ServiceItem(
        title: 'Emergency Fuel & EV Boost',
        subtitle: 'Fuel delivery and mobile charging support',
        icon: Icons.ev_station_rounded,
        color: AppColors.fuel,
        type: 'Fuel',
      ),
    ];

    return Column(
      children: services
          .map(
            (service) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: GlassCard(
                padding: const EdgeInsets.all(13),
                onTap: () => _openService(service.type),
                child: Row(
                  children: [
                    GlassIconBox(
                      icon: service.icon,
                      color: service.color,
                      size: 44,
                      iconSize: 22,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  service.title,
                                  style: const TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (service.badge != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: service.color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    service.badge!,
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w800,
                                      color: service.color,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            service.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white30
                          : AppColors.textHintLight,
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildCostEstimatorCard(bool isDark, VehicleModel? vehicle) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.costEstimator,
        arguments: {'vehicle': vehicle},
      ),
      child: Row(
        children: [
          const GlassIconBox(
            icon: Icons.calculate_rounded,
            color: AppColors.primary,
            size: 44,
            iconSize: 22,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Dynamic Cost Estimator',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.tertiary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: AppColors.tertiary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Estimate cost by vehicle, issue, distance and labor',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: isDark ? Colors.white30 : AppColors.textHintLight,
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyPatrol(bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          const Row(
            children: [
              GlassIconBox(
                icon: Icons.radar_rounded,
                size: 34,
                iconSize: 18,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Nearby Fleet Patrol',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '4 trucks • 3.5 mi',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 142,
              child: Stack(
                children: [
                  const Positioned.fill(child: _MiniMap()),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: GlassPill(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.tertiary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Highway 80 Sector 4 • clear shoulders',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white70
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponderCard(bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Certified Responders',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.tertiary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded,
                        size: 12, color: AppColors.tertiary),
                    SizedBox(width: 3),
                    Text(
                      '100% vetted',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.tertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.engineering_rounded,
                    color: Colors.white, size: 25),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Rajan Auto Works',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? Colors.white
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded,
                            size: 14, color: AppColors.primary),
                      ],
                    ),
                    Text(
                      'Master Mechanic • Heavy Tow Certified',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Row(
                      children: [
                        Icon(Icons.star_rounded,
                            size: 13, color: AppColors.starRating),
                        SizedBox(width: 2),
                        Text(
                          '5.0',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          '• 1,420 rescues',
                          style: TextStyle(fontSize: 9.5),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentProtection(
    bool isDark,
    ServiceRequestModel? request,
  ) {
    final active = request;
    final hasRequest = active != null && active.id.isNotEmpty;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent Protection',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RequestHistoryScreen(),
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('History'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GlassPill(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                GlassIconBox(
                  icon: hasRequest
                      ? _serviceIcon(active.serviceType)
                      : Icons.history_rounded,
                  size: 38,
                  iconSize: 19,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasRequest ? active.serviceType : 'No recent requests',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        hasRequest
                            ? '${_formatDate(active.date)} • ${active.status.label}'
                            : 'Your completed assistance will appear here',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasRequest)
                  TextButton(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.activeAssistance,
                      arguments: {'request': active},
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 34),
                    ),
                    child: const Text('View'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB).withValues(alpha: isDark ? 0.15 : 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.warning, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Breakdown safety rules',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Turn on hazard lights, raise the hood if safe, and stay inside the vehicle with seatbelts fastened on highway shoulders.',
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.4,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_rounded,
                size: 13, color: AppColors.tertiary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'Encrypted roadside dispatch • RoadRescue Shield',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          'Average response 11.4 mins in metropolitan areas',
          style: TextStyle(
            fontSize: 9,
            color: isDark ? AppColors.textHintDark : AppColors.textHintLight,
          ),
        ),
      ],
    );
  }

  IconData _vehicleIcon(String type) {
    switch (type) {
      case 'Bike':
        return Icons.two_wheeler_rounded;
      case 'Bus':
        return Icons.directions_bus_rounded;
      case 'Heavy Vehicle':
        return Icons.local_shipping_rounded;
      case 'Light Commercial Vehicle':
        return Icons.local_shipping_outlined;
      default:
        return Icons.directions_car_rounded;
    }
  }

  IconData _serviceIcon(String serviceType) {
    final normalized = serviceType.toLowerCase();
    if (normalized.contains('puncture') || normalized.contains('tyre')) {
      return Icons.tire_repair_rounded;
    }
    if (normalized.contains('tow')) return Icons.fire_truck_rounded;
    if (normalized.contains('battery')) return Icons.electric_bolt_rounded;
    if (normalized.contains('fuel')) return Icons.ev_station_rounded;
    return Icons.car_repair_rounded;
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _ServiceItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? badge;
  final String type;

  const _ServiceItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.type,
    this.badge,
  });
}

class _MiniMap extends StatelessWidget {
  const _MiniMap();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RoutePainter(),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE0ECFF), Color(0xFFD6E5FB), Color(0xFFCDDFF8)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 34,
              top: 34,
              child: _pin(Icons.local_shipping_rounded, AppColors.primary),
            ),
            Positioned(
              right: 40,
              bottom: 38,
              child: _pin(Icons.fmd_bad_rounded, AppColors.secondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pin(IconData icon, Color color) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, size: 15, color: color),
    );
  }
}

class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;
    final route = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(-20, size.height * 0.25)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.32,
        size.width * 0.55,
        size.height * 0.62,
        size.width + 20,
        size.height * 0.78,
      );
    canvas.drawPath(path, road);
    canvas.drawPath(path, route);

    final cross = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    final crossPath = Path()
      ..moveTo(size.width * 0.15, -10)
      ..lineTo(size.width * 0.42, size.height + 10);
    canvas.drawPath(crossPath, cross);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


