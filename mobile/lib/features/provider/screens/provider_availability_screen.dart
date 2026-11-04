import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routes/app_routes.dart';
import '../../../services/location_service.dart';
import '../../../services/provider_service.dart';
import '../../../widgets/rr_button.dart';
import '../../../widgets/rr_card.dart';

class ProviderAvailabilityScreen extends StatefulWidget {
  const ProviderAvailabilityScreen({super.key});

  @override
  State<ProviderAvailabilityScreen> createState() => _ProviderAvailabilityScreenState();
}

class _ProviderAvailabilityScreenState extends State<ProviderAvailabilityScreen> {
  bool _is24x7 = true;
  double _serviceRadius = 25.0; // km
  double? _latitude;
  double? _longitude;
  bool _isUpdatingLocation = false;
  bool _mechanicEnabled = true;
  bool _punctureEnabled = true;
  bool _towEnabled = true;
  bool _batteryEnabled = true;

  bool _hydraulicJack = true;
  bool _airCompressor = true;
  bool _heavyTowRig = true;
  bool _jumpStarter24V = true;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final account = await ProviderService.getProfile();
      if (mounted) {
        setState(() {
          _serviceRadius = account.providerProfile.serviceRadiusKm.clamp(5.0, 50.0);
          _latitude = account.providerProfile.latitude;
          _longitude = account.providerProfile.longitude;
        });
      }
    } catch (_) {}
  }

  Future<void> _updateLocationWithGps() async {
    setState(() => _isUpdatingLocation = true);
    try {
      final loc = await LocationService.getCurrentLocation();
      final updated = await ProviderService.updateLocation(
        latitude: loc.latitude,
        longitude: loc.longitude,
      );
      if (!mounted) return;
      setState(() {
        _latitude = updated.latitude;
        _longitude = updated.longitude;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dispatch GPS base updated: ${loc.formattedCoordinates}'),
          backgroundColor: AppColors.success,
        ),
      );
    } on LocationServiceDisabledException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.danger,
          action: SnackBarAction(
            label: 'Settings',
            textColor: Colors.white,
            onPressed: () => LocationService.openLocationSettings(),
          ),
        ),
      );
    } on LocationPermissionDeniedForeverException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.danger,
          action: SnackBarAction(
            label: 'Settings',
            textColor: Colors.white,
            onPressed: () => LocationService.openAppSettings(),
          ),
        ),
      );
    } on LocationPermissionDeniedException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.danger,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update location: ${e.toString().replaceFirst('ApiException', '').trim()}'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUpdatingLocation = false);
    }
  }

  void _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      // Save serviceRadiusKm to backend
      await ProviderService.updateProfile(serviceRadiusKm: _serviceRadius);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Availability and service preferences saved!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('ApiException', '').trim()),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coverage & Availability'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Operating Mode Card
              RRCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '24/7 Emergency Dispatch',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Receive urgent night-time highway breakdown alerts',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: _is24x7,
                          activeThumbColor: AppColors.primary,
                          onChanged: (v) => setState(() => _is24x7 = v),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Highway Coverage Radius
              const SectionHeader(title: 'Service Coverage Radius'),
              const SizedBox(height: 12),
              RRCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Maximum Travel Distance',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_serviceRadius.toInt()} km',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Slider(
                      value: _serviceRadius,
                      min: 5,
                      max: 50,
                      divisions: 9,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _serviceRadius = v),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('5 km', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black45)),
                        Text('25 km', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black45)),
                        Text('50 km', style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black45)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Dispatch GPS Base Location Card
              const SectionHeader(title: 'Dispatch Base GPS Location'),
              const SizedBox(height: 12),
              RRCard(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (_latitude != null && _longitude != null)
                            ? AppColors.success.withValues(alpha: 0.12)
                            : AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.gps_fixed_rounded,
                        color: (_latitude != null && _longitude != null)
                            ? AppColors.success
                            : AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (_latitude != null && _longitude != null)
                                ? 'Lat: ${_latitude!.toStringAsFixed(5)}, Lng: ${_longitude!.toStringAsFixed(5)}'
                                : 'No GPS location registered',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            (_latitude != null && _longitude != null)
                                ? 'Center point for coverage radius'
                                : 'Update to calibrate dispatch center',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _isUpdatingLocation
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            icon: const Icon(Icons.my_location_rounded),
                            tooltip: 'Calibrate via Device GPS',
                            color: AppColors.primary,
                            onPressed: _updateLocationWithGps,
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Supported Services Toggles
              const SectionHeader(title: 'Offered Assistance Services'),
              const SizedBox(height: 12),
              RRCard(
                child: Column(
                  children: [
                    _buildSwitchTile('Mechanical Repairs', _mechanicEnabled, (v) => setState(() => _mechanicEnabled = v)),
                    const Divider(),
                    _buildSwitchTile('Puncture & Tyre Service', _punctureEnabled, (v) => setState(() => _punctureEnabled = v)),
                    const Divider(),
                    _buildSwitchTile('Tow Truck / Recovery', _towEnabled, (v) => setState(() => _towEnabled = v)),
                    const Divider(),
                    _buildSwitchTile('24V Heavy Vehicle Jump-Start', _batteryEnabled, (v) => setState(() => _batteryEnabled = v)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Heavy Vehicle Specialized Equipment
              const SectionHeader(title: 'Heavy Vehicle Equipment Checklist'),
              const SizedBox(height: 12),
              RRCard(
                child: Column(
                  children: [
                    _buildSwitchTile('Hydraulic Bottle Jack (30 Ton)', _hydraulicJack, (v) => setState(() => _hydraulicJack = v)),
                    const Divider(),
                    _buildSwitchTile('Heavy Duty Air Compressor', _airCompressor, (v) => setState(() => _airCompressor = v)),
                    const Divider(),
                    _buildSwitchTile('Heavy Tow Arm / Winch Rig', _heavyTowRig, (v) => setState(() => _heavyTowRig = v)),
                    const Divider(),
                    _buildSwitchTile('24V Dual-Battery Booster Pack', _jumpStarter24V, (v) => setState(() => _jumpStarter24V = v)),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Save button
              RRButton(
                label: 'Save Coverage Settings',
                icon: Icons.check_rounded,
                isLoading: _isSaving,
                onPressed: _saveSettings,
              ),
              const SizedBox(height: 24),

              // Help & Legal
              const SectionHeader(title: 'Help & Legal'),
              const SizedBox(height: 12),
              RRCard(
                child: Column(
                  children: [
                    _buildHelpTile(
                      icon: Icons.help_outline_rounded,
                      title: 'Help & FAQ',
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.faq),
                    ),
                    const Divider(),
                    _buildHelpTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy Policy & Terms',
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.privacyPolicy,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 21, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool val, ValueChanged<bool> onChanged) {    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: val,
            activeThumbColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
