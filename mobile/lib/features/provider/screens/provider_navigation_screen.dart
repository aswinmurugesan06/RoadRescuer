import 'dart:async';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/distance_util.dart';
import '../../../models/service_request_model.dart';
import '../../../services/location_service.dart';
import '../../../services/phone_service.dart';
import '../../../services/provider_service.dart';
import '../../../services/service_request_service.dart';
import '../../../services/socket_service.dart';
import '../../../services/routing_service.dart';
import '../../../widgets/rr_button.dart';
import '../../../widgets/rr_map_view.dart';

class ProviderNavigationScreen extends StatefulWidget {
  final ServiceRequestModel? request;

  const ProviderNavigationScreen({super.key, this.request});

  @override
  State<ProviderNavigationScreen> createState() => _ProviderNavigationScreenState();
}

class _ProviderNavigationScreenState extends State<ProviderNavigationScreen> {
  DeviceLocation? _providerLocation;
  double? _lastRouteLat;
  double? _lastRouteLng;

  double? _distanceKm;
  int? _etaMinutes;
  List<LatLng> _routeCoordinates = [];
  bool _isRouting = false;
  bool _locationLoading = true;
  Timer? _gpsTimer;

  @override
  void initState() {
    super.initState();
    _connectSocketAndStartGps();
    if (widget.request != null) {
      ServiceRequestService.updateStatus(widget.request!.id, 'ARRIVING')
          .catchError((_) => widget.request!);
    }
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    final reqId = widget.request?.id;
    if (reqId != null && reqId.isNotEmpty) {
      SocketService.instance.leaveRequestRoom(reqId);
    }
    super.dispose();
  }

  Future<void> _connectSocketAndStartGps() async {
    final reqId = widget.request?.id;
    if (reqId != null && reqId.isNotEmpty) {
      await SocketService.instance.connect();
      SocketService.instance.joinRequestRoom(reqId);
    }

    await _fetchAndBroadcastLocation();

    // Periodic live GPS broadcast every 8 seconds
    _gpsTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _fetchAndBroadcastLocation();
    });
  }

  Future<void> _fetchAndBroadcastLocation() async {
    try {
      final loc = await LocationService.getCurrentLocation();
      if (!mounted) return;
      final req = widget.request;

      setState(() {
        _providerLocation = loc;
        _locationLoading = false;
      });

      // Update provider location in database
      try {
        await ProviderService.updateLocation(
          latitude: loc.latitude,
          longitude: loc.longitude,
        );
      } catch (_) {}

      // Broadcast real-time location to customer via Socket.IO
      if (req != null && req.id.isNotEmpty) {
        SocketService.instance.sendProviderLocation(
          requestId: req.id,
          latitude: loc.latitude,
          longitude: loc.longitude,
        );
      }

      // Check if route needs initial calculation or recalculation (> 100m moved)
      if (req?.customerLatitude != null && req?.customerLongitude != null) {
        final custLat = req!.customerLatitude!;
        final custLng = req.customerLongitude!;

        final shouldRecalculate = _lastRouteLat == null ||
            _lastRouteLng == null ||
            DistanceUtil.calculateDistance(
                  _lastRouteLat!,
                  _lastRouteLng!,
                  loc.latitude,
                  loc.longitude,
                ) >
                0.1;

        if (shouldRecalculate && !_isRouting) {
          _calculateRoute(loc.latitude, loc.longitude, custLat, custLng);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  Future<void> _calculateRoute(
    double originLat,
    double originLng,
    double destLat,
    double destLng,
  ) async {
    if (!mounted) return;
    setState(() => _isRouting = true);

    try {
      final route = await RoutingService.getDirections(
        originLat: originLat,
        originLng: originLng,
        destLat: destLat,
        destLng: destLng,
      );

      if (!mounted) return;
      setState(() {
        _lastRouteLat = originLat;
        _lastRouteLng = originLng;
        _distanceKm = route.distanceKm;
        _etaMinutes = route.durationMinutes;
        _routeCoordinates = route.coordinates;
        _isRouting = false;
      });
    } catch (_) {
      if (!mounted) return;
      final directDist = DistanceUtil.calculateDistance(originLat, originLng, destLat, destLng);
      setState(() {
        _distanceKm = directDist;
        _etaMinutes = (directDist / 30.0 * 60).round().clamp(2, 120);
        _isRouting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final req = widget.request;

    final customerLat = req?.customerLatitude ?? MapConfig.defaultLatitude;
    final customerLng = req?.customerLongitude ?? MapConfig.defaultLongitude;
    final provLat = _providerLocation?.latitude;
    final provLng = _providerLocation?.longitude;

    // Additional markers: Provider live marker + Customer breakdown destination
    final markers = <RRMapMarker>[
      RRMapMarker(
        id: 'customer_destination',
        latitude: customerLat,
        longitude: customerLng,
        label: 'BREAKDOWN LOCATION',
        color: AppColors.danger,
      ),
      if (provLat != null && provLng != null)
        RRMapMarker(
          id: 'provider_live_location',
          latitude: provLat,
          longitude: provLng,
          label: 'MY LOCATION',
          color: AppColors.primary,
        ),
    ];

    final distanceLabel = _distanceKm != null
        ? DistanceUtil.formatDistance(_distanceKm)
        : '--';
    final etaLabel = _etaMinutes != null ? '$_etaMinutes min' : '-- min';

    final vehicleDesc = req != null
        ? '${req.vehicleModel}${req.customerName != null ? " (${req.customerName})" : ""}'
        : 'Assistance Vehicle';
    final customerMobile = req?.customerMobile;
    final requestId = req?.id;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // MapLibre + OpenFreeMap with turn-by-turn route polyline
            Positioned.fill(
              child: RRMapView(
                latitude: provLat ?? customerLat,
                longitude: provLng ?? customerLng,
                routeCoordinates: _routeCoordinates,
                routeColor: AppColors.primary,
                routeWidth: 5.0,
                additionalMarkers: markers,
                showControls: true,
                showMarker: false,
                initialZoom: 14.5,
              ),
            ),

            // Top navigation header banner
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.navigation_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Turn-by-turn Navigation Active',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            req?.location ?? req?.customerAddress ?? 'Customer Breakdown Spot',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Navigation Card
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _locationLoading || _isRouting
                                  ? const Text(
                                      'Calculating route & ETA...',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    )
                                  : Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            '$distanceLabel • $etaLabel',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                              const SizedBox(height: 4),
                              Text(
                                vehicleDesc,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (requestId != null)
                                Text(
                                  'Request #${requestId.substring(0, 8).toUpperCase()}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondaryLight,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            final opened =
                                await PhoneService.call(customerMobile);
                            if (!opened && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Could not open the phone dialer.'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.call_rounded,
                            color: AppColors.primary,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    RRButton(
                      label: 'I Have Arrived at Location',
                      icon: Icons.check_circle_outline_rounded,
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        if (widget.request != null) {
                          try {
                            await ServiceRequestService.updateStatus(widget.request!.id, 'IN_SERVICE');
                          } catch (_) {}
                        }
                        nav.pushReplacementNamed(
                          AppRoutes.providerServicePin,
                          arguments: {'request': widget.request},
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
