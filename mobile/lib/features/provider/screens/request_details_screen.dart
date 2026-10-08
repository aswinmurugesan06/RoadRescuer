import 'package:flutter/material.dart';
import '../../../routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/distance_util.dart';
import '../../../models/service_request_model.dart';
import '../../../services/location_service.dart';
import '../../../services/service_request_service.dart';
import '../../../widgets/rr_button.dart';
import '../../../widgets/rr_card.dart';
import '../../../widgets/rr_map_view.dart';
import '../../../widgets/rr_status_badge.dart';

class RequestDetailsScreen extends StatefulWidget {
  final ServiceRequestModel? request;

  const RequestDetailsScreen({super.key, this.request});

  @override
  State<RequestDetailsScreen> createState() => _RequestDetailsScreenState();
}

class _RequestDetailsScreenState extends State<RequestDetailsScreen> {
  bool _isAccepting = false;
  DeviceLocation? _providerLocation;
  double? _distanceKm;

  @override
  void initState() {
    super.initState();
    _fetchProviderLocation();
  }

  /// Fetch provider's GPS to calculate distance to the breakdown spot.
  Future<void> _fetchProviderLocation() async {
    try {
      final loc = await LocationService.getCurrentLocation();
      if (!mounted) return;
      final req = widget.request;
      setState(() {
        _providerLocation = loc;
        if (req?.customerLatitude != null && req?.customerLongitude != null) {
          _distanceKm = DistanceUtil.calculateDistance(
            loc.latitude,
            loc.longitude,
            req!.customerLatitude!,
            req.customerLongitude!,
          );
        }
      });
    } catch (_) {
      // GPS unavailable — distance shows as "--"
    }
  }

  Future<void> _acceptJob() async {
    final req = widget.request;

    if (req == null) {
      // No real request — navigate with demo data
      Navigator.pushReplacementNamed(context, AppRoutes.providerNavigation);
      return;
    }

    setState(() => _isAccepting = true);
    try {
      final accepted = await ServiceRequestService.acceptRequest(req.id);
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.providerNavigation,
        arguments: {'request': accepted},
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to accept: ${e.toString()}'),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final req = widget.request;

    // Values for display from real service request model
    final vehicleModel = req?.vehicleModel.isNotEmpty == true ? req!.vehicleModel : 'Assistance Vehicle';
    final vehiclePlate = req?.vehiclePlate.isNotEmpty == true ? req!.vehiclePlate : 'Not specified';
    final vehicleClass = req?.vehicleType?.isNotEmpty == true ? req!.vehicleType! : 'Commercial Vehicle';
    final serviceType = req?.serviceType ?? 'Mechanic';
    final problem = req?.problem.isNotEmpty == true ? req!.problem : 'Roadside Assistance';
    final locationText = req?.location.isNotEmpty == true ? req!.location : 'Breakdown Location';
    final distanceLabel = _distanceKm != null
        ? DistanceUtil.formatDistance(_distanceKm)
        : (req?.distanceFromProvider != null
            ? '${req!.distanceFromProvider!.toStringAsFixed(1)} km'
            : '-- km');
    final lat = req?.customerLatitude;
    final lng = req?.customerLongitude;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incoming Request Details'),
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
                    // Urgency Banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.emergency_rounded, color: AppColors.primary, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$serviceType Breakdown',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  problem,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          RRStatusBadge(
                            label: distanceLabel,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Vehicle Specifications
                    const SectionHeader(title: 'Breakdown Vehicle Details'),
                    const SizedBox(height: 12),
                    RRCard(
                      child: Column(
                        children: [
                          InfoRow(label: 'Vehicle Model', value: vehicleModel),
                          const Divider(),
                          InfoRow(label: 'Plate Number', value: vehiclePlate),
                          const Divider(),
                          InfoRow(label: 'Vehicle Class', value: vehicleClass),
                          const Divider(),
                          InfoRow(label: 'Service Required', value: serviceType),
                          const Divider(),
                          InfoRow(label: 'Reported Issue', value: problem),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Location card with real MapLibre map
                    const SectionHeader(title: 'Breakdown Spot Location'),
                    const SizedBox(height: 12),
                    RRCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.place_rounded, color: AppColors.primary, size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  locationText,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (_distanceKm != null)
                            Text(
                              'Distance: ${DistanceUtil.formatDistance(_distanceKm)} away • ETA ~${DistanceUtil.etaMinutes(_distanceKm!)} at 30 km/h'
                              '${_providerLocation != null ? " (GPS accuracy: ${_providerLocation!.accuracyLabel})" : ""}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            )
                          else
                            Text(
                              'Calculating distance from your current location...',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          const SizedBox(height: 12),
                          // MapLibre map showing customer's breakdown location
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              height: 180,
                              child: RRMapView(
                                latitude: lat,
                                longitude: lng,
                                showControls: false,
                                showMarker: lat != null && lng != null,
                                markerTitle: 'BREAKDOWN',
                                markerColor: AppColors.danger,
                                initialZoom: 14.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Privacy notice (PENDING/SEARCHING: contact masked)
                    if (req != null && (req.status == RequestStatus.pending || req.status == RequestStatus.searching))
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.privacy_tip_rounded, color: AppColors.warning, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Customer contact details are revealed after you accept the job.',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Customer contact (ACCEPTED: contact visible)
                    if (req == null || req.status == RequestStatus.accepted || req.customerMobile != null) ...[
                      const SectionHeader(title: 'Customer / Driver Contact'),
                      const SizedBox(height: 12),
                      RRCard(
                        child: Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: AppColors.secondary,
                              child: Icon(Icons.person_rounded, color: Colors.white),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    req?.customerName?.isNotEmpty == true
                                        ? req!.customerName!
                                        : 'Customer',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    req?.customerMobile?.isNotEmpty == true
                                        ? req!.customerMobile!
                                        : 'Contact available upon arrival',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (req?.customerMobile != null)
                              IconButton(
                                icon: const Icon(Icons.call_rounded, color: AppColors.primary),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Calling ${req!.customerMobile}...'),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Action Buttons Bar
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
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: RRButton(
                      label: 'Accept & Navigate',
                      icon: Icons.navigation_rounded,
                      isLoading: _isAccepting,
                      onPressed: _acceptJob,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

