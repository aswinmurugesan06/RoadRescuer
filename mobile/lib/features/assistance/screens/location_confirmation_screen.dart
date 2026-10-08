import 'package:flutter/material.dart';
import '../../../routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/service_request_model.dart';
import '../../../services/location_service.dart';
import '../../../services/service_request_service.dart';
import '../../../widgets/rr_button.dart';
import '../../../widgets/rr_card.dart';
import '../../../widgets/rr_map_view.dart';
import '../../../widgets/rr_text_field.dart';

class LocationConfirmationScreen extends StatefulWidget {
  final String serviceType;
  final String problem;
  final VehicleModel? vehicle;

  const LocationConfirmationScreen({
    super.key,
    required this.serviceType,
    required this.problem,
    this.vehicle,
  });

  @override
  State<LocationConfirmationScreen> createState() =>
      _LocationConfirmationScreenState();
}

class _LocationConfirmationScreenState
    extends State<LocationConfirmationScreen> {
  final _landmarkController =
      TextEditingController(text: 'Opposite HP Petrol Bunk, KM 82');

  DeviceLocation? _deviceLocation;
  bool _isLocating = false;
  bool _isCreatingRequest = false;
  String? _locationError;
  String? _errorType; // 'disabled' | 'denied' | 'deniedForever' | 'generic'
  String _currentAddress = 'Detecting current GPS coordinates...';

  @override
  void initState() {
    super.initState();
    _fetchDeviceLocation();
  }

  @override
  void dispose() {
    _landmarkController.dispose();
    super.dispose();
  }

  Future<void> _fetchDeviceLocation() async {
    setState(() {
      _isLocating = true;
      _locationError = null;
      _errorType = null;
      _currentAddress = 'Acquiring GPS fix via device satellite sensors...';
    });

    try {
      final loc = await LocationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _deviceLocation = loc;
        _isLocating = false;
        _currentAddress =
            'Lat: ${loc.latitude.toStringAsFixed(6)}, Lng: ${loc.longitude.toStringAsFixed(6)} (Accuracy: ${loc.accuracyLabel})';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'GPS Location locked: ${loc.formattedCoordinates} (${loc.accuracyLabel})',
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    } on LocationServiceDisabledException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLocating = false;
        _errorType = 'disabled';
        _locationError = e.message;
        _currentAddress = 'Location services disabled on device';
      });
    } on LocationPermissionDeniedForeverException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLocating = false;
        _errorType = 'deniedForever';
        _locationError = e.message;
        _currentAddress = 'Location permission permanently denied';
      });
    } on LocationPermissionDeniedException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLocating = false;
        _errorType = 'denied';
        _locationError = e.message;
        _currentAddress = 'Location permission denied by user';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLocating = false;
        _errorType = 'generic';
        _locationError =
            'Unable to acquire GPS fix. Please verify location settings.';
        _currentAddress = 'GPS acquisition failed';
      });
    }
  }

  Future<void> _submitRequest() async {
    if (_deviceLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for GPS fix before submitting.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isCreatingRequest = true);

    try {
      final landmark = _landmarkController.text.trim();
      final address = _currentAddress.isNotEmpty ? _currentAddress : null;
      final combinedAddress =
          (landmark.isNotEmpty && address != null && address.isNotEmpty)
              ? '$address — $landmark'
              : (landmark.isNotEmpty ? landmark : address);

      final ServiceRequestModel created = await ServiceRequestService.createRequest(
        serviceType: widget.serviceType,
        problemDescription: widget.problem,
        customerLatitude: _deviceLocation!.latitude,
        customerLongitude: _deviceLocation!.longitude,
        customerAddress: combinedAddress,
        vehicleId: widget.vehicle?.id,
        vehiclePlate: widget.vehicle?.plateNumber,
        vehicleModel: widget.vehicle != null
            ? '${widget.vehicle!.manufacturer} ${widget.vehicle!.model}'
            : null,
        vehicleType: widget.vehicle?.type,
        category: widget.serviceType,
      );

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.activeAssistance,
        (r) => r.isFirst,
        arguments: {'request': created},
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create request: ${e.toString()}'),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isCreatingRequest = false);
    }
  }

  Widget _buildErrorBanner() {
    if (_locationError == null) return const SizedBox.shrink();

    IconData icon;
    String buttonText;
    VoidCallback onAction;

    switch (_errorType) {
      case 'disabled':
        icon = Icons.location_off_rounded;
        buttonText = 'Enable GPS';
        onAction = () async {
          await LocationService.openLocationSettings();
          _fetchDeviceLocation();
        };
        break;
      case 'deniedForever':
        icon = Icons.settings_suggest_rounded;
        buttonText = 'Open Settings';
        onAction = () async {
          await LocationService.openAppSettings();
          _fetchDeviceLocation();
        };
        break;
      case 'denied':
        icon = Icons.security_rounded;
        buttonText = 'Grant Permission';
        onAction = _fetchDeviceLocation;
        break;
      default:
        icon = Icons.refresh_rounded;
        buttonText = 'Retry GPS';
        onAction = _fetchDeviceLocation;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.danger, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _locationError!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: AppColors.danger,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              icon: Icon(icon, size: 16),
              label: Text(buttonText,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
              onPressed: onAction,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vehicleDisplay = widget.vehicle != null
        ? '${widget.vehicle!.displayName} (${widget.vehicle!.plateNumber})'
        : 'Ashok Leyland 2820 (TN 38 AB 1234)';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Location'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // MapLibre Map View with OpenFreeMap vector tiles & device GPS
                    SizedBox(
                      height: 240,
                      width: double.infinity,
                      child: RRMapView(
                        latitude: _deviceLocation?.latitude,
                        longitude: _deviceLocation?.longitude,
                        showControls: true,
                        showMarker: true,
                        markerTitle: _deviceLocation != null
                            ? 'GPS LOCKED'
                            : 'BREAKDOWN SPOT',
                        markerColor: _deviceLocation != null
                            ? AppColors.success
                            : AppColors.primary,
                        onLocationUpdated: _fetchDeviceLocation,
                      ),
                    ),

                    // Content below map
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Error banner if any
                          _buildErrorBanner(),

                          // GPS Address & Coordinates card
                          RRCard(
                            child: Column(
                              children: [
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: (_deviceLocation != null
                                                ? AppColors.success
                                                : AppColors.primary)
                                            .withOpacity(0.12),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        _deviceLocation != null
                                            ? Icons.gps_fixed_rounded
                                            : Icons.place_rounded,
                                        color: _deviceLocation != null
                                            ? AppColors.success
                                            : AppColors.primary,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment
                                                    .spaceBetween,
                                            children: [
                                              const Text(
                                                'Device GPS Location',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors
                                                      .textSecondaryLight,
                                                ),
                                              ),
                                              if (_deviceLocation != null)
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.success
                                                        .withOpacity(0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                  child: Text(
                                                    _deviceLocation!
                                                        .accuracyLabel,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: AppColors.success,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            _currentAddress,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          if (_deviceLocation != null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'Coordinates: ${_deviceLocation!.formattedCoordinates}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark
                                                    ? AppColors
                                                        .textSecondaryDark
                                                    : AppColors
                                                        .textSecondaryLight,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: _isLocating
                                        ? null
                                        : _fetchDeviceLocation,
                                    icon: const Icon(
                                        Icons.refresh_rounded,
                                        size: 16),
                                    label: const Text(
                                      'Re-detect GPS Location',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Landmark Input
                          RRTextField(
                            label: 'Nearby Landmark / Highway KM',
                            hint:
                                'e.g. Near Toll Gate, KM 82 marker, Northbound lane',
                            controller: _landmarkController,
                            prefixIcon: Icons.signpost_outlined,
                          ),
                          const SizedBox(height: 24),

                          // Summary of Service
                          const SectionHeader(title: 'Request Summary'),
                          const SizedBox(height: 12),
                          RRCard(
                            child: Column(
                              children: [
                                InfoRow(
                                    label: 'Service Type',
                                    value: widget.serviceType),
                                const Divider(),
                                InfoRow(
                                    label: 'Reported Issue',
                                    value: widget.problem),
                                const Divider(),
                                InfoRow(
                                    label: 'Vehicle',
                                    value: vehicleDisplay),
                                if (_deviceLocation != null) ...[
                                  const Divider(),
                                  InfoRow(
                                    label: 'GPS Coordinates',
                                    value:
                                        _deviceLocation!.formattedCoordinates,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom CTA
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
                label: 'Confirm Location & Request Help',
                icon: Icons.emergency_rounded,
                isLoading: _isCreatingRequest,
                onPressed: _isCreatingRequest ? null : _submitRequest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
