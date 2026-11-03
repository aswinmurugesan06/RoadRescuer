import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/navigation/route_observer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/provider_model.dart';
import '../../../models/service_request_model.dart';
import '../../../routes/app_routes.dart';
import '../../../services/location_service.dart';
import '../../../services/provider_service.dart';
import '../../../services/service_request_service.dart';
import '../../../services/socket_service.dart';
import '../../../widgets/app_logo.dart';
import '../../../widgets/glass.dart';
import 'provider_earnings_screen.dart';

class ProviderHomeScreen extends StatefulWidget {
  const ProviderHomeScreen({super.key});

  @override
  State<ProviderHomeScreen> createState() => _ProviderHomeScreenState();
}

class _ProviderHomeScreenState extends State<ProviderHomeScreen>
    with RouteAware, WidgetsBindingObserver {
  bool _isOnline = false;
  bool _isTogglingAvailability = false;
  bool _isUpdatingLocation = false;
  bool _isLoadingRequests = false;
  bool _isAccepting = false;
  bool _routeSubscribed = false;
  DeviceLocation? _currentDeviceLocation;
  ProviderAccountModel? _account;
  List<ServiceRequestModel> _availableRequests = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProfile();
    _initSocket();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      if (_routeSubscribed) {
        appRouteObserver.unsubscribe(this);
      }
      appRouteObserver.subscribe(this, route);
      _routeSubscribed = true;
    }
  }

  @override
  void didPopNext() {
    // A job screen was closed — reload so accepted/completed requests do not
    // linger in the "available jobs" list.
    _refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    await _loadProfile();
    if (_isOnline) await _loadAvailableRequests();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_routeSubscribed) appRouteObserver.unsubscribe(this);
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
          if (!_isOnline) {
            _availableRequests = [];
            _isLoadingRequests = false;
          }
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
      final requests = await ServiceRequestService.getAvailableRequests();
      if (mounted) {
        setState(() {
          _availableRequests = requests;
          _isLoadingRequests = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingRequests = false);
    }
  }

  String _distanceLabel(ServiceRequestModel request) {
    final pLat =
        _currentDeviceLocation?.latitude ?? _account?.providerProfile.latitude;
    final pLng =
        _currentDeviceLocation?.longitude ?? _account?.providerProfile.longitude;
    if (pLat != null &&
        pLng != null &&
        request.customerLatitude != null &&
        request.customerLongitude != null) {
      final distance = _haversine(
        pLat,
        pLng,
        request.customerLatitude!,
        request.customerLongitude!,
      );
      return '${distance.toStringAsFixed(1)} km';
    }
    return 'Nearby';
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.pow(math.sin(dLon / 2), 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  Future<void> _toggleAvailability(bool value) async {
    final profile = _account?.providerProfile;
    if (profile == null) return;

    if (value && profile.verificationStatus != 'APPROVED') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot go online — your account is ${profile.verificationStatus}. Contact support for approval.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final target = value ? 'AVAILABLE' : 'OFFLINE';
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
        if (value) {
          _updateLocationWithGps();
          _loadAvailableRequests();
        } else {
          setState(() => _availableRequests = []);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value ? 'Online: ready to receive jobs' : 'Offline: no incoming jobs',
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.toString().replaceFirst('ApiException', '').trim(),
            ),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTogglingAvailability = false);
    }
  }

  Future<void> _updateLocationWithGps() async {
    setState(() => _isUpdatingLocation = true);
    try {
      final location = await LocationService.getCurrentLocation();
      final updated = await ProviderService.updateLocation(
        latitude: location.latitude,
        longitude: location.longitude,
      );
      if (!mounted) return;
      setState(() {
        _isUpdatingLocation = false;
        _currentDeviceLocation = location;
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
            'GPS broadcast updated: ${location.formattedCoordinates} (${location.accuracyLabel})',
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isUpdatingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update GPS: $error'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _acceptRequest(ServiceRequestModel request) async {
    setState(() => _isAccepting = true);
    try {
      final accepted = await ServiceRequestService.acceptRequest(request.id);
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        AppRoutes.providerNavigation,
        arguments: {'request': accepted},
      ).then((_) => _loadAvailableRequests());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not accept job: $error'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  Future<void> _declineRequest(ServiceRequestModel request) async {
    try {
      await ServiceRequestService.rejectRequest(
        request.id,
        reason: 'Declined from provider dashboard',
      );
      if (mounted) {
        setState(() => _availableRequests.removeWhere((item) => item.id == request.id));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _availableRequests.removeWhere((item) => item.id == request.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = _account?.providerProfile;
    final firstName = (_account?.name ?? 'Technician').split(RegExp(r'\s+')).first;
    final urgent = _availableRequests.isNotEmpty ? _availableRequests.first : null;
    final queued = _availableRequests.length > 1
        ? _availableRequests.sublist(1)
        : <ServiceRequestModel>[];

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: GlassBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              await _loadProfile();
              await _loadAvailableRequests();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(isDark, firstName),
                  const SizedBox(height: 16),
                  _buildProfileCard(isDark, profile, firstName),
                  const SizedBox(height: 14),
                  if (urgent != null) ...[
                    _buildUrgentCard(isDark, urgent),
                    const SizedBox(height: 18),
                  ],
                  if (_isLoadingRequests && _availableRequests.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_availableRequests.isEmpty)
                    _buildEmptyQueue(isDark),
                  if (queued.isNotEmpty) ...[
                    GlassSectionHeading(
                      title: 'Available Nearby',
                      subtitle: '${queued.length} more request${queued.length == 1 ? '' : 's'} in your area',
                    ),
                    const SizedBox(height: 8),
                    ...queued.map(
                      (request) => Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: _buildQueueItem(isDark, request),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  const GlassSectionHeading(
                    title: 'Crew Tools',
                    subtitle: 'Everything you need for the next job',
                  ),
                  const SizedBox(height: 8),
                  _buildTool(
                    isDark,
                    icon: Icons.map_rounded,
                    color: AppColors.primary,
                    title: 'Navigation & GPS',
                    subtitle: 'Live traffic and route guidance',
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.providerAvailability,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildTool(
                    isDark,
                    icon: Icons.payments_rounded,
                    color: AppColors.success,
                    title: 'Daily earnings & settlements',
                    subtitle: 'Gross billing, commission and net payout',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProviderEarningsScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildTool(
                    isDark,
                    icon: Icons.calculate_rounded,
                    color: AppColors.tertiary,
                    title: 'Dynamic cost estimator',
                    subtitle: 'Estimate by vehicle, issue, distance and labor',
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.costEstimator,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildTool(
                    isDark,
                    icon: Icons.tune_rounded,
                    color: AppColors.secondary,
                    title: 'Coverage & availability',
                    subtitle: 'Service radius, base location and capabilities',
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.providerAvailability,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildTelemetryCard(isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, String firstName) {
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
              'Technician Hub',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
                color: secondary,
              ),
            ),
          ],
        ),
        const Spacer(),
        _iconButton(
          icon: Icons.notifications_none_rounded,
          onTap: () => Navigator.pushNamed(context, AppRoutes.notifications),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
              ),
            ),
            child: Center(
              child: Text(
                firstName.isNotEmpty ? firstName[0].toUpperCase() : 'R',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _iconButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withOpacity(0.06)
              : Colors.white.withOpacity(0.72),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withOpacity(0.08)
                : Colors.white,
          ),
        ),
        child: Icon(icon, size: 21),
      ),
    );
  }

  Widget _buildProfileCard(
    bool isDark,
    ProviderProfileData? profile,
    String firstName,
  ) {
    final secondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final radius = profile?.serviceRadiusKm ?? 25;
    final totalJobs = profile?.totalJobs ?? 0;
    final rating = profile?.rating ?? 0;
    final category = profile?.categoryLabel ?? 'Mechanic';
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                  ),
                  borderRadius: BorderRadius.circular(17),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(Icons.engineering_rounded,
                    color: Colors.white, size: 27),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome $firstName',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_account?.providerProfile.garageName ?? 'Independent specialist'} • $category',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: secondary),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _isTogglingAvailability
                    ? null
                    : () => _toggleAvailability(!_isOnline),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isOnline
                        ? AppColors.success.withOpacity(0.12)
                        : (isDark
                            ? Colors.white.withOpacity(0.06)
                            : Colors.white.withOpacity(0.8)),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _isOnline
                          ? AppColors.success.withOpacity(0.3)
                          : (isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.white),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isOnline
                              ? AppColors.success
                              : AppColors.offline,
                          shape: BoxShape.circle,
                          boxShadow: _isOnline
                              ? [
                                  BoxShadow(
                                    color: AppColors.success.withOpacity(0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isTogglingAvailability
                            ? '…'
                            : (_isOnline ? 'ONLINE' : 'OFFLINE'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: _isOnline
                              ? AppColors.success
                              : secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          GestureDetector(
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.providerAvailability,
            ),
            child: GlassPill(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              child: Row(
                children: [
                  const GlassIconBox(
                    icon: Icons.my_location_rounded,
                    size: 30,
                    iconSize: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_account?.providerProfile.businessAddress ?? 'Service base'} • ${radius.toStringAsFixed(0)} km',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                  Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.tune_rounded,
                      size: 14, color: AppColors.primary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              _metric('TODAY', '${_availableRequests.length} jobs', AppColors.primary, isDark),
              _metric('TOTAL JOBS', '$totalJobs', AppColors.success, isDark),
              _metric('RATING', '★ ${rating.toStringAsFixed(2)}', AppColors.starRating, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, Color color, bool isDark) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.04)
              : Colors.white.withOpacity(0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: isDark ? Colors.white38 : AppColors.textHintLight,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrgentCard(bool isDark, ServiceRequestModel request) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.warning.withOpacity(0.14),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: GlassCard(
        borderColor: AppColors.warning.withOpacity(0.35),
        color: isDark
            ? AppColors.cardDark.withOpacity(0.92)
            : Colors.white.withOpacity(0.86),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.warning.withOpacity(0.25),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded,
                          size: 13, color: AppColors.warning),
                      SizedBox(width: 3),
                      Text(
                        'NEW DISPATCH',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                GlassPill(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 13, color: AppColors.danger),
                      const SizedBox(width: 3),
                      Text(
                        '42s',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white70 : AppColors.textPrimaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${request.serviceType} assistance',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded,
                              size: 15,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              request.customerName ?? 'Customer',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                            '• ${request.vehicleModel}',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  request.totalAmount > 0
                      ? '₹${request.totalAmount.toStringAsFixed(0)}'
                      : 'Estimate',
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GlassPill(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded,
                      size: 15, color: AppColors.secondary),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      request.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                  Text(
                    '${_distanceLabel(request)} • ~8 min',
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
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _declineRequest(request),
                    icon: const Icon(Icons.close_rounded, size: 17),
                    label: const Text('Decline'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      foregroundColor: AppColors.textSecondaryLight,
                      side: BorderSide(
                        color: isDark
                            ? Colors.white.withOpacity(0.12)
                            : AppColors.borderLight,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isAccepting ? null : () => _acceptRequest(request),
                    icon: _isAccepting
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_rounded, size: 17),
                    label: const Text('Accept Job'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      backgroundColor: AppColors.primary,
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

  Widget _buildQueueItem(bool isDark, ServiceRequestModel request) {
    return GlassCard(
      padding: const EdgeInsets.all(13),
      onTap: () => Navigator.pushNamed(
        context,
        AppRoutes.requestDetails,
        arguments: {'request': request},
      ),
      child: Row(
        children: [
          GlassIconBox(
            icon: _serviceIcon(request.serviceType),
            size: 44,
            iconSize: 22,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.serviceType,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${request.vehicleModel} • ${_distanceLabel(request)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  request.totalAmount > 0
                      ? '₹${request.totalAmount.toStringAsFixed(0)}'
                      : 'Estimate on arrival',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.requestDetails,
              arguments: {'request': request},
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 36),
            ),
            child: const Text('Review'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyQueue(bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          const GlassIconBox(
            icon: Icons.radar_rounded,
            size: 46,
            iconSize: 23,
            color: AppColors.tertiary,
          ),
          const SizedBox(height: 9),
          Text(
            _isOnline ? 'No requests in your area yet' : 'Go online to receive jobs',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            _isOnline
                ? 'New dispatches will appear here in real time.'
                : 'Toggle your status above to start receiving nearby requests.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTool(
    bool isDark, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(13),
      onTap: onTap,
      child: Row(
        children: [
          GlassIconBox(icon: icon, color: color, size: 40, iconSize: 20),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
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

  Widget _buildTelemetryCard(bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          const GlassIconBox(
            icon: Icons.verified_rounded,
            color: AppColors.success,
            size: 36,
            iconSize: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Vehicle telemetry synced • OBD-II active',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : AppColors.textPrimaryLight,
              ),
            ),
          ),
          Text(
            _isUpdatingLocation ? 'Updating…' : 'Signal 98%',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
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
}
