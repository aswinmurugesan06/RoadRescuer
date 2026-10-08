import 'package:flutter/material.dart';
import '../../../routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/mock_data.dart';
import '../../../models/vehicle_model.dart';
import '../../../services/vehicle_service.dart';
import '../../../widgets/rr_button.dart';
import '../../../widgets/rr_card.dart';

class RequestAssistanceScreen extends StatefulWidget {
  const RequestAssistanceScreen({super.key});

  @override
  State<RequestAssistanceScreen> createState() => _RequestAssistanceScreenState();
}

class _RequestAssistanceScreenState extends State<RequestAssistanceScreen> {
  List<VehicleModel> _vehicles = MockData.userVehicles;
  late VehicleModel _selectedVehicle;
  String _selectedService = 'Mechanic';

  final List<Map<String, dynamic>> _services = [
    {
      'type': 'Mechanic',
      'title': 'Mechanical Repair',
      'desc': 'Engine, brakes, clutch, electrical & transmission repairs',
      'icon': Icons.build_rounded,
      'color': AppColors.mechanic,
    },
    {
      'type': 'Puncture',
      'title': 'Tyre & Puncture Service',
      'desc': 'Flat tyres, punctures, tube replacement & air refills',
      'icon': Icons.tire_repair_rounded,
      'color': AppColors.puncture,
    },
    {
      'type': 'Tow',
      'title': 'Tow Truck / Recovery',
      'desc': 'Flatbed & heavy towing for lorries, trucks & breakdowns',
      'icon': Icons.local_shipping_rounded,
      'color': AppColors.tow,
    },
    {
      'type': 'Battery',
      'title': 'Battery Jump-Start',
      'desc': 'Dead battery boost, jump-start, terminals & alternator test',
      'icon': Icons.battery_charging_full_rounded,
      'color': AppColors.battery,
    },
    {
      'type': 'Fuel',
      'title': 'Emergency Fuel Delivery',
      'desc': 'Diesel or petrol delivered directly to your breakdown spot',
      'icon': Icons.local_gas_station_rounded,
      'color': AppColors.fuel,
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedVehicle = _vehicles.firstWhere((v) => v.isDefault, orElse: () => _vehicles.first);
    _loadCustomerVehicles();
  }

  Future<void> _loadCustomerVehicles() async {
    try {
      final realVehicles = await VehicleService.getMyVehicles();
      if (realVehicles.isNotEmpty && mounted) {
        setState(() {
          _vehicles = realVehicles;
          _selectedVehicle = realVehicles.firstWhere((v) => v.isDefault, orElse: () => realVehicles.first);
        });
      }
    } catch (_) {
      // Retain fallback vehicles
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Assistance'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Emergency notice banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.danger.withOpacity(0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.emergency_share_rounded, color: AppColors.danger, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  '24/7 Highway & City Support',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.danger,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Choose service required. Verified providers respond in minutes.',
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Vehicle selector
                    const SectionHeader(title: 'Breakdown Vehicle'),
                    const SizedBox(height: 12),
                    RRCard(
                      child: Column(
                        children: _vehicles.map((v) {
                          final isSelected = v.id == _selectedVehicle.id;
                          return InkWell(
                            onTap: () => setState(() => _selectedVehicle = v),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withOpacity(0.08)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: isSelected
                                    ? Border.all(color: AppColors.primary, width: 1.5)
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Radio<String>(
                                    value: v.id,
                                    groupValue: _selectedVehicle.id,
                                    activeColor: AppColors.primary,
                                    onChanged: (val) {
                                      setState(() => _selectedVehicle = v);
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          v.plateNumber,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                        Text(
                                          '${v.manufacturer} ${v.model} (${v.type})',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? AppColors.textSecondaryDark
                                                : AppColors.textSecondaryLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (v.isDefault)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Default',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Service type selector
                    const SectionHeader(title: 'Select Required Service'),
                    const SizedBox(height: 12),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _services.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final s = _services[i];
                        final isSelected = _selectedService == s['type'];
                        final color = s['color'] as Color;

                        return InkWell(
                          onTap: () => setState(() => _selectedService = s['type'] as String),
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.cardDark : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? color : (isDark ? AppColors.dividerDark : AppColors.dividerLight),
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: color.withOpacity(0.2),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(s['icon'] as IconData, color: color, size: 26),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s['title'] as String,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected ? color : null,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        s['desc'] as String,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                  color: isSelected ? color : (isDark ? Colors.white30 : Colors.black26),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Bottom bar
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: RRButton(
                label: 'Continue — Select Problem',
                icon: Icons.arrow_forward_rounded,
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.selectProblem,
                    arguments: {
                      'serviceType': _selectedService,
                      'vehicle': _selectedVehicle,
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
