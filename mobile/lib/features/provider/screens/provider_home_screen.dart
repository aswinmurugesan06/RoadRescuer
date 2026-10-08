import 'package:flutter/material.dart';
import '../../../routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/provider_model.dart';
import '../../../services/location_service.dart';
import '../../../services/provider_service.dart';
import '../../../services/service_request_service.dart';
import '../../../services/socket_service.dart';
import '../../../core/utils/distance_util.dart';
import '../../../models/service_request_model.dart';
import '../../../widgets/rr_card.dart';
import '../../../widgets/rr_status_badge.dart';
import '../../../widgets/app_logo.dart';

class ProviderHomeScreen extends StatefulWidget {
  const ProviderHomeScreen({super.key});

  @override
  State<ProviderHomeScreen> createState() => _ProviderHomeScreenState();
}

class _ProviderHomeScreenState extends State<ProviderHomeScreen> {
  bool _isOnline = false;
  bool _isTogglingAvailability = false;
  bool _isUpdatingLocation = false;
  DeviceLocation? _currentDeviceLocation;
  ProviderAccountModel? _account;
  List<ServiceRequestModel> _availableRequests = [];
  bool _isLoadingRequests = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _initSocket();
  }

  @override
  void dispose() {
    SocketService.instance.clearProviderListeners();
    super.dispose();
  }

  Future<void> _initSocket() async {
    await SocketService.instance.connect();
    SocketService.instance.onNewRequest = (data) {
      if (_isOnline && mounted) {
        _loadAvailableRequests();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New emergency request available nearby!'),
            backgroundColor: AppColors.primary,
            duration: Duration(seconds: 3),
          ),
        );
      }
    };
  }

  Future<void> _loadProfile() async {
    try {
      final account = await ProviderService.getProfile();
      if (mounted) {
        setState(() {
          _account = account;
          _isOnline = account.providerProfile.availability == 'AVAILABLE';
        });
        if (account.providerProfile.availability == 'AVAILABLE') {
          _loadAvailableRequests();
        }
      }
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadAvailableRequests() async {
    if (!_isOnline) {
      if (mounted) setState(() => _availableRequests = []);
      return;
    }
    setState(() => _isLoadingRequests = true);
    try {
      final reqs = await ServiceRequestService.getAvailableRequests();
      if (mounted) {
        setState(() {
          _availableRequests = reqs;
          _isLoadingRequests = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingRequests = false);
    }
  }

  String _calculateDistanceLabel(ServiceRequestModel req) {
    final pLat = _currentDeviceLocation?.latitude ?? _account?.providerProfile.latitude;
    final pLng = _currentDeviceLocation?.longitude ?? _account?.providerProfile.longitude;
    if (pLat != null && pLng != null && req.customerLatitude != null && req.customerLongitude != null) {
      final dist = DistanceUtil.calculateDistance(pLat, pLng, req.customerLatitude!, req.customerLongitude!);
      return '${DistanceUtil.formatDistance(dist)} away';
    }
    if (req.distanceFromProvider != null) {
      return '~${req.distanceFromProvider!.toStringAsFixed(1)} km away';
    }
    return '~3.5 km away';
  }

  Future<void> _toggleAvailability(bool val) async {
    final profile = _account?.providerProfile;
    if (profile == null) return;

    // Block PENDING/REJECTED/SUSPENDED from going AVAILABLE
    if (val && profile.verificationStatus != 'APPROVED') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot go online — your account is ${profile.verificationStatus}. '  
            'Contact support for approval.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    // Block manually setting BUSY (should never reach UI but guard anyway)
    final target = val ? 'AVAILABLE' : 'OFFLINE';

    setState(() => _isTogglingAvailability = true);
    try {
      final updated = await ProviderService.setAvailability(target);
      if (mounted) {
        setState(() {
          _isOnline = updated.availability == 'AVAILABLE';
          if (_account != null) {
            _account = ProviderAccountModel.fromJson({
              'id': _account!.id,
              'name': _account!.name,
              'email': _account!.email,
              'mobile': _account!.mobile,
              'role': _account!.role,
              'isVerified': _account!.isVerified,
              'isActive': _account!.isActive,
              'createdAt': _account!.createdAt.toIso8601String(),
              'providerProfile': {
                'id': updated.id,
                'userId': updated.userId,
                'category': updated.category,
                'verificationStatus': updated.verificationStatus,
                'availability': updated.availability,
                'garageName': updated.garageName,
                'businessAddress': updated.businessAddress,
                'serviceRadiusKm': updated.serviceRadiusKm,
                'latitude': updated.latitude,
                'longitude': updated.longitude,
                'rating': updated.rating,
                'totalJobs': updated.totalJobs,
                'createdAt': updated.createdAt.toIso8601String(),
                'updatedAt': updated.updatedAt.toIso8601String(),
              },
            });
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(val ? 'Online: Ready to receive jobs' : 'Offline: No incoming jobs'),
            duration: const Duration(seconds: 1),
          ),
        );
        if (val) {
          _updateLocationWithGps();
          _loadAvailableRequests();
        } else {
          setState(() => _availableRequests = []);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('ApiException', '').trim()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTogglingAvailability = false);
    }
  }

  void _showLocationErrorDialog({
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.location_off_rounded, color: AppColors.danger),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 16)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.pop(ctx);
              onAction();
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
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
        _isUpdatingLocation = false;
        _currentDeviceLocation = loc;
        if (_account != null) {
          _account = ProviderAccountModel.fromJson({
            'id': _account!.id,
            'name': _account!.name,
            'email': _account!.email,
            'mobile': _account!.mobile,
            'role': _account!.role,
            'isVerified': _account!.isVerified,
            'isActive': _account!.isActive,
            'createdAt': _account!.createdAt.toIso8601String(),
            'providerProfile': {
              'id': updated.id,
              'userId': updated.userId,
              'category': updated.category,
              'verificationStatus': updated.verificationStatus,
              'availability': updated.availability,
              'garageName': updated.garageName,
              'businessAddress': updated.businessAddress,
              'serviceRadiusKm': updated.serviceRadiusKm,
              'latitude': updated.latitude,
              'longitude': updated.longitude,
              'rating': updated.rating,
              'totalJobs': updated.totalJobs,
              'createdAt': updated.createdAt.toIso8601String(),
              'updatedAt': updated.updatedAt.toIso8601String(),
            },
          });
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'GPS broadcast updated: ${loc.formattedCoordinates} (${loc.accuracyLabel})',
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    } on LocationServiceDisabledException catch (e) {
      if (!mounted) return;
      setState(() => _isUpdatingLocation = false);
      _showLocationErrorDialog(
        title: 'Location Service Disabled',
        message: e.message,
        actionLabel: 'Open Location Settings',
        onAction: () async {
          await LocationService.openLocationSettings();
          _updateLocationWithGps();
        },
      );
    } on LocationPermissionDeniedForeverException catch (e) {
      if (!mounted) return;
      setState(() => _isUpdatingLocation = false);
      _showLocationErrorDialog(
        title: 'Location Permission Denied',
        message: e.message,
        actionLabel: 'Open App Settings',
        onAction: () async {
          await LocationService.openAppSettings();
          _updateLocationWithGps();
        },
      );
    } on LocationPermissionDeniedException catch (e) {
      if (!mounted) return;
      setState(() => _isUpdatingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.danger,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUpdatingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update GPS location: ${e.toString().replaceFirst('ApiException', '').trim()}',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            AppLogo.appBar(
              height: 28,
            ),
            SizedBox(width: 8),
            Text('Provider Dashboard'),
          ],
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Service Settings',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.providerAvailability),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Online / Offline Status Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isOnline
                        ? [const Color(0xFF0F2E1E), const Color(0xFF1B4D3E)]
                        : [const Color(0xFF262626), const Color(0xFF333333)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: (_isOnline ? AppColors.success : Colors.black).withOpacity(0.2),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isOnline ? const Color(0xFF00E676) : Colors.grey,
                                boxShadow: _isOnline
                                    ? [
                                        const BoxShadow(
                                          color: Color(0xFF00E676),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _isOnline ? 'YOU ARE ONLINE' : 'YOU ARE OFFLINE',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: _isOnline ? const Color(0xFF00E676) : Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                        _isTogglingAvailability
                            ? const SizedBox(
                                width: 36,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF00E676),
                                ),
                              )
                            : Switch(
                                value: _isOnline,
                                activeColor: const Color(0xFF00E676),
                                onChanged: _toggleAvailability,
                              ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _isOnline
                            ? 'Ready for emergency calls on NH 44 & nearby roads'
                            : 'Toggle switch to start receiving breakdown requests',
                        style: const TextStyle(fontSize: 13, color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Verification Status Warning Banner
              if (_account != null && _account!.providerProfile.verificationStatus != 'APPROVED')
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warning.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Account ${_account!.providerProfile.verificationStatus} — '
                          'You cannot go online until approved.',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Garage Identity Card
              RRCard(
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.garage_rounded, color: AppColors.secondary, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _account?.providerProfile.garageName ?? _account?.name ?? 'Your Garage',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(width: 6),
                              if (_account?.providerProfile.verificationStatus == 'APPROVED')
                                const Icon(Icons.verified_rounded, size: 16, color: AppColors.secondary),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _account?.providerProfile.categoryLabel ?? 'Service Provider',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                          ),
                        ],
                      ),
                    ),
                    RRStarRating(rating: _account?.providerProfile.rating ?? 5.0),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // GPS Location Broadcast Card
              RRCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: (_account?.providerProfile.latitude != null ||
                                    _currentDeviceLocation != null)
                                ? AppColors.success.withOpacity(0.12)
                                : AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.gps_fixed_rounded,
                            color: (_account?.providerProfile.latitude != null ||
                                    _currentDeviceLocation != null)
                                ? AppColors.success
                                : AppColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  const Text(
                                    'GPS Location Broadcast',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (_account?.providerProfile.latitude != null ||
                                      _currentDeviceLocation != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'BROADCASTING',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.success,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                (_account?.providerProfile.latitude != null)
                                    ? 'Lat: ${_account!.providerProfile.latitude!.toStringAsFixed(5)}, Lng: ${_account!.providerProfile.longitude!.toStringAsFixed(5)}'
                                    : 'No GPS broadcast yet',
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
                        const SizedBox(width: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.map_rounded),
                              tooltip: 'View on Map',
                              color: AppColors.secondary,
                              onPressed: () => Navigator.pushNamed(
                                context,
                                AppRoutes.providerNavigation,
                              ),
                            ),
                            const SizedBox(width: 4),
                            _isUpdatingLocation
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.all(6),
                                    constraints: const BoxConstraints(),
                                    icon: const Icon(Icons.my_location_rounded),
                                    tooltip: 'Broadcast Current GPS',
                                    color: AppColors.primary,
                                    onPressed: _updateLocationWithGps,
                                  ),
                          ],
                        ),
                      ],
                    ),
                    if (_currentDeviceLocation != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Device accuracy: ${_currentDeviceLocation!.accuracyLabel}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Today's Stats Row
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      label: 'Jobs Today',
                      value: '4',
                      icon: Icons.check_circle_outline_rounded,
                      color: AppColors.primary,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      label: "Today's Earned",
                      value: '₹4,850',
                      icon: Icons.currency_rupee_rounded,
                      color: AppColors.success,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      label: 'Acceptance',
                      value: '96%',
                      icon: Icons.trending_up_rounded,
                      color: AppColors.secondary,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Incoming Requests Feed
              if (_isOnline) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SectionHeader(
                      title: 'Incoming Requests (${_availableRequests.length})',
                    ),
                    IconButton(
                      icon: _isLoadingRequests
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded, size: 20),
                      onPressed: _isLoadingRequests ? null : _loadAvailableRequests,
                      tooltip: 'Refresh Available Jobs',
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_availableRequests.isEmpty && !_isLoadingRequests)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cardDark : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.radar_rounded,
                          size: 40,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Listening for Emergency Calls',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'No unassigned ${_account?.providerProfile.categoryLabel ?? "roadside"} requests in your area right now.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),

                for (final req in _availableRequests)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cardDark : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.primary, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            RRStatusBadge(
                              label: req.category ?? 'URGENT ASSISTANCE',
                              color: AppColors.primary,
                            ),
                            Text(
                              _calculateDistanceLabel(req),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          req.vehicleModel.isNotEmpty ? req.vehicleModel : 'Vehicle Breakdown',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Plate: ${req.vehiclePlate.isNotEmpty ? req.vehiclePlate : "Unknown"} • ${req.problem}',
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                req.location,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    _availableRequests.removeWhere((r) => r.id == req.id);
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Request dismissed')),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.danger,
                                  side: const BorderSide(color: AppColors.danger),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text('Decline'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.requestDetails,
                                    arguments: {'request': req},
                                  ).then((_) {
                                    _loadAvailableRequests();
                                  });
                                },
                                icon: const Icon(Icons.visibility_rounded, size: 18),
                                label: const Text('View & Accept'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                    ),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.cloud_off_rounded, color: Colors.grey, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'You are currently OFFLINE. Toggle online above to start receiving incoming roadside requests.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Quick Actions
              const SectionHeader(title: 'Quick Operations'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildOperationButton(
                      title: 'Active Job',
                      icon: Icons.construction_rounded,
                      color: AppColors.primary,
                      onTap: () => Navigator.pushNamed(context, AppRoutes.activeJob),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildOperationButton(
                      title: 'Create Bill',
                      icon: Icons.receipt_long_rounded,
                      color: AppColors.secondary,
                      onTap: () => Navigator.pushNamed(context, AppRoutes.createBill),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildOperationButton(
                      title: 'Working Area',
                      icon: Icons.my_location_rounded,
                      color: AppColors.mechanic,
                      onTap: () => Navigator.pushNamed(context, AppRoutes.providerAvailability),
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
