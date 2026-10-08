import 'package:flutter/material.dart';
import '../../../routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/vehicle_model.dart';
import '../../../services/vehicle_service.dart';
import '../../../services/api_client.dart';
import '../../../widgets/rr_card.dart';
import '../../../widgets/rr_button.dart';

class VehicleDetailsScreen extends StatefulWidget {
  final VehicleModel? vehicle;

  const VehicleDetailsScreen({super.key, this.vehicle});

  @override
  State<VehicleDetailsScreen> createState() => _VehicleDetailsScreenState();
}

class _VehicleDetailsScreenState extends State<VehicleDetailsScreen> {
  VehicleModel? _vehicle;
  bool _isSettingDefault = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _vehicle = widget.vehicle;
  }

  Future<void> _setDefault(bool setAsDefault) async {
    if (_vehicle == null || !setAsDefault || _vehicle!.isDefault) return;

    setState(() => _isSettingDefault = true);
    try {
      final updated = await VehicleService.setDefaultVehicle(_vehicle!.id);
      if (mounted) {
        setState(() {
          _vehicle = updated;
          _isSettingDefault = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Set as default vehicle'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _isSettingDefault = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSettingDefault = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to set default vehicle.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _confirmDelete() {
    if (_vehicle == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Vehicle'),
        content:
            Text('Are you sure you want to remove ${_vehicle!.plateNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteVehicle();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteVehicle() async {
    if (_vehicle == null) return;
    setState(() => _isDeleting = true);
    try {
      await VehicleService.deleteVehicle(_vehicle!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vehicle ${_vehicle!.plateNumber} removed.'),
            backgroundColor: AppColors.danger,
          ),
        );
        // Return true so MyVehiclesScreen refreshes
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete vehicle.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_vehicle == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vehicle Details')),
        body: const Center(child: Text('Vehicle details not available')),
      );
    }
    final vehicle = _vehicle!;

    return Scaffold(
      appBar: AppBar(
        title: Text(vehicle.model),
        actions: [
          if (_isDeleting)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator()),
            )
          else
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.danger),
              onPressed: _confirmDelete,
              tooltip: 'Delete Vehicle',
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vehicle Header Hero Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            vehicle.typeIcon,
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                        if (vehicle.isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'DEFAULT VEHICLE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      vehicle.plateNumber,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${vehicle.manufacturer} • ${vehicle.model}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFCBD5E1),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Vehicle Specs Card
              const SectionHeader(title: 'Vehicle Information'),
              const SizedBox(height: 12),
              RRCard(
                child: Column(
                  children: [
                    InfoRow(label: 'Category', value: vehicle.type),
                    const Divider(),
                    InfoRow(
                        label: 'Manufacturer', value: vehicle.manufacturer),
                    const Divider(),
                    InfoRow(label: 'Model', value: vehicle.model),
                    const Divider(),
                    InfoRow(
                        label: 'Registration Plate',
                        value: vehicle.plateNumber),
                    const Divider(),
                    InfoRow(
                        label: 'Manufacturing Year',
                        value: vehicle.year ?? '—'),
                    const Divider(),
                    InfoRow(
                        label: 'Vehicle Color',
                        value: vehicle.color ?? '—'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Set as Default toggle
              RRCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Primary Emergency Vehicle',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Selected automatically on SOS tap',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryLight),
                        ),
                      ],
                    ),
                    _isSettingDefault
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Switch(
                            value: vehicle.isDefault,
                            activeColor: AppColors.primary,
                            onChanged: vehicle.isDefault
                                ? null // can't un-default without choosing another
                                : (v) => _setDefault(v),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              // Bottom Request Assistance CTA
              RRButton(
                label: 'Request Assistance for this Vehicle',
                icon: Icons.emergency_rounded,
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.requestAssistance),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
