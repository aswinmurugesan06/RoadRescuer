import 'package:flutter/material.dart';
import 'package:maplibre_gl/mapbox_gl.dart';
import '../core/theme/app_colors.dart';
import '../services/location_service.dart';

/// Configuration constants for RoadRescue Map integration.
class MapConfig {
  MapConfig._();

  /// OpenFreeMap Liberty style URL (Free, fast vector tiles based on OSM data).
  static const String openFreeMapLiberty =
      'https://tiles.openfreemap.org/styles/liberty';

  /// OpenFreeMap Bright style URL.
  static const String openFreeMapBright =
      'https://tiles.openfreemap.org/styles/bright';

  /// Default fallback coordinates (Bangalore tech/transport hub).
  static const double defaultLatitude = 12.971598;
  static const double defaultLongitude = 77.594562;
  static const double defaultZoom = 15.0;
}

/// Marker configuration for extra pins on RRMapView.
class RRMapMarker {
  final String id;
  final double latitude;
  final double longitude;
  final String label;
  final Color color;

  const RRMapMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.color,
  });
}

/// Reusable RoadRescue map component powered by MapLibre and OpenFreeMap.
/// Supports real device GPS, route polylines, multiple markers, and navigation controls.
class RRMapView extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final double? initialLatitude;
  final double? initialLongitude;
  final double initialZoom;
  final bool showControls;
  final bool showMarker;
  final bool showUserLocation;
  final List<RRMapMarker> additionalMarkers;
  final List<LatLng>? routeCoordinates;
  final Color routeColor;
  final double routeWidth;
  final String markerTitle;
  final Color markerColor;
  final String styleString;
  final ValueChanged<MaplibreMapController>? onMapCreated;
  final VoidCallback? onLocationUpdated;

  const RRMapView({
    super.key,
    this.latitude,
    this.longitude,
    this.initialLatitude,
    this.initialLongitude,
    this.initialZoom = MapConfig.defaultZoom,
    this.showControls = true,
    this.showMarker = true,
    this.showUserLocation = true,
    this.additionalMarkers = const [],
    this.routeCoordinates,
    this.routeColor = AppColors.primary,
    this.routeWidth = 4.5,
    this.markerTitle = 'YOU ARE HERE',
    this.markerColor = AppColors.primary,
    this.styleString = MapConfig.openFreeMapLiberty,
    this.onMapCreated,
    this.onLocationUpdated,
  });

  double? get effectiveLatitude => latitude ?? initialLatitude;
  double? get effectiveLongitude => longitude ?? initialLongitude;

  @override
  State<RRMapView> createState() => RRMapViewState();
}

class RRMapViewState extends State<RRMapView> {
  MaplibreMapController? _controller;
  bool _isMapReady = false;
  bool _isLoadingLocation = false;
  String? _mapError;

  double? _currentLat;
  double? _currentLng;

  @override
  void initState() {
    super.initState();
    _currentLat = widget.effectiveLatitude;
    _currentLng = widget.effectiveLongitude;

    if (widget.showUserLocation && (_currentLat == null || _currentLng == null)) {
      _initLocation();
    }
  }

  @override
  void didUpdateWidget(RRMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.effectiveLatitude != oldWidget.effectiveLatitude ||
        widget.effectiveLongitude != oldWidget.effectiveLongitude) {
      if (widget.effectiveLatitude != null && widget.effectiveLongitude != null) {
        _currentLat = widget.effectiveLatitude;
        _currentLng = widget.effectiveLongitude;
        if (widget.routeCoordinates == null || widget.routeCoordinates!.isEmpty) {
          _animateToCurrent();
        }
      }
    }
    if (widget.additionalMarkers != oldWidget.additionalMarkers) {
      _updateAdditionalMarkers();
    }
    if (widget.routeCoordinates != oldWidget.routeCoordinates) {
      _drawRoutePolyline();
    }
  }

  Future<void> _initLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      final loc = await LocationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _currentLat = loc.latitude;
        _currentLng = loc.longitude;
        _isLoadingLocation = false;
      });
      if (widget.routeCoordinates == null || widget.routeCoordinates!.isEmpty) {
        _animateToCurrent();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _currentLat ??= MapConfig.defaultLatitude;
        _currentLng ??= MapConfig.defaultLongitude;
        _isLoadingLocation = false;
      });
    }
  }

  void _onMapCreated(MaplibreMapController controller) {
    _controller = controller;
    widget.onMapCreated?.call(controller);
  }

  void _onStyleLoaded() {
    if (!mounted) return;
    setState(() {
      _isMapReady = true;
      _mapError = null;
    });
    _updateAdditionalMarkers();
    _drawRoutePolyline();
  }

  Future<void> _updateAdditionalMarkers() async {
    if (_controller == null || !_isMapReady) return;
    try {
      await _controller!.clearCircles();
      for (final m in widget.additionalMarkers) {
        final colorHex =
            '#${m.color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
        await _controller!.addCircle(
          CircleOptions(
            geometry: LatLng(m.latitude, m.longitude),
            circleColor: colorHex,
            circleRadius: 10,
            circleStrokeWidth: 2,
            circleStrokeColor: '#FFFFFF',
          ),
        );
      }
    } catch (_) {
      // Safely ignore map annotation errors
    }
  }

  Future<void> _drawRoutePolyline() async {
    if (_controller == null || !_isMapReady) return;
    final coords = widget.routeCoordinates;
    if (coords == null || coords.isEmpty) return;

    try {
      await _controller!.clearLines();
      final colorHex =
          '#${widget.routeColor.value.toRadixString(16).padLeft(8, '0').substring(2)}';

      await _controller!.addLine(
        LineOptions(
          geometry: coords,
          lineColor: colorHex,
          lineWidth: widget.routeWidth,
          lineOpacity: 0.85,
          lineJoin: 'round',
        ),
      );

      // Fit camera bounds to route
      if (coords.length >= 2) {
        double minLat = coords.first.latitude;
        double maxLat = coords.first.latitude;
        double minLng = coords.first.longitude;
        double maxLng = coords.first.longitude;

        for (final p in coords) {
          if (p.latitude < minLat) minLat = p.latitude;
          if (p.latitude > maxLat) maxLat = p.latitude;
          if (p.longitude < minLng) minLng = p.longitude;
          if (p.longitude > maxLng) maxLng = p.longitude;
        }

        _controller!.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(minLat - 0.003, minLng - 0.003),
              northeast: LatLng(maxLat + 0.003, maxLng + 0.003),
            ),
          ),
        );
      }
    } catch (_) {
      // Safely handle polyline drawing errors
    }
  }

  /// Recenter the camera to the user's current GPS location.
  Future<void> recenterOnLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      final loc = await LocationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _currentLat = loc.latitude;
        _currentLng = loc.longitude;
        _isLoadingLocation = false;
      });
      _animateToCurrent();
      widget.onLocationUpdated?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not get GPS fix: ${e.toString()}'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _animateToCurrent() {
    if (_controller != null && _currentLat != null && _currentLng != null) {
      _controller!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentLat!, _currentLng!),
          widget.initialZoom,
        ),
      );
    }
  }

  void _zoomIn() {
    _controller?.animateCamera(CameraUpdate.zoomIn());
  }

  void _zoomOut() {
    _controller?.animateCamera(CameraUpdate.zoomOut());
  }

  @override
  Widget build(BuildContext context) {
    final lat = _currentLat ?? MapConfig.defaultLatitude;
    final lng = _currentLng ?? MapConfig.defaultLongitude;

    return Stack(
      children: [
        // ── MapLibre Map View ─────────────────────────────────────────
        MaplibreMap(
          styleString: widget.styleString,
          initialCameraPosition: CameraPosition(
            target: LatLng(lat, lng),
            zoom: widget.initialZoom,
          ),
          onMapCreated: _onMapCreated,
          onStyleLoadedCallback: _onStyleLoaded,
          trackCameraPosition: true,
          compassEnabled: true,
          myLocationEnabled: false,
          tiltGesturesEnabled: false,
          rotateGesturesEnabled: true,
          scrollGesturesEnabled: true,
          zoomGesturesEnabled: true,
        ),

        // ── Center Location Pin / Marker ──────────────────────────────
        if (widget.showMarker)
          Center(
            child: FractionalTranslation(
              translation: const Offset(0.0, -0.5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.markerColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: widget.markerColor.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.markerTitle,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Pin Icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.markerColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.emergency_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Map Loading Indicator ─────────────────────────────────────
        if (!_isMapReady && _mapError == null)
          Positioned.fill(
            child: Container(
              color: const Color(0xFF1E293B).withOpacity(0.85),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Loading OpenFreeMap tiles...',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── Map Error State ───────────────────────────────────────────
        if (_mapError != null)
          Positioned.fill(
            child: Container(
              color: Colors.black87,
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.map_outlined,
                        color: AppColors.warning, size: 36),
                    const SizedBox(height: 8),
                    Text(
                      _mapError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _mapError = null);
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Retry Map'),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── Map Controls (Zoom In, Zoom Out, Recenter) ────────────────
        if (widget.showControls)
          Positioned(
            right: 14,
            bottom: 36,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMapButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Zoom In',
                  onTap: _zoomIn,
                ),
                const SizedBox(height: 8),
                _buildMapButton(
                  icon: Icons.remove_rounded,
                  tooltip: 'Zoom Out',
                  onTap: _zoomOut,
                ),
                const SizedBox(height: 8),
                _buildMapButton(
                  icon: _isLoadingLocation
                      ? null
                      : Icons.my_location_rounded,
                  tooltip: 'Recenter on My GPS',
                  color: AppColors.primary,
                  iconColor: Colors.white,
                  isLoading: _isLoadingLocation,
                  onTap: recenterOnLocation,
                ),
              ],
            ),
          ),

        // ── Map Attribution / Source Badge ────────────────────────────
        Positioned(
          left: 10,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '© OpenFreeMap © OpenStreetMap',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapButton({
    IconData? icon,
    required String tooltip,
    required VoidCallback onTap,
    Color color = Colors.white,
    Color iconColor = const Color(0xFF1E293B),
    bool isLoading = false,
  }) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black38,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: isLoading ? null : onTap,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(icon, color: iconColor, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}
