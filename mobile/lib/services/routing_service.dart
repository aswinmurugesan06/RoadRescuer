import 'package:maplibre_gl/mapbox_gl.dart';
import 'api_client.dart';
import '../core/utils/distance_util.dart';

/// Encapsulates calculated route data including turn-by-turn polyline geometry,
/// distance in kilometers, and estimated travel time in minutes.
class RouteData {
  final double distanceKm;
  final int durationMinutes;
  final List<LatLng> coordinates;
  final String provider;

  const RouteData({
    required this.distanceKm,
    required this.durationMinutes,
    required this.coordinates,
    required this.provider,
  });

  String get formattedDistance => DistanceUtil.formatDistance(distanceKm);
  String get formattedDuration => '$durationMinutes min';
}

/// Service for calculating directions, road routes, and ETAs.
/// Communicates with backend routing engine (OSRM / OpenFreeMap compatible).
class RoutingService {
  RoutingService._();

  /// Calculate route between origin and destination coordinates.
  static Future<RouteData> getDirections({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    try {
      final res = await ApiClient.get(
        '/routing/directions?originLat=$originLat&originLng=$originLng&destLat=$destLat&destLng=$destLng',
      );

      final data = res['data'] as Map<String, dynamic>?;
      if (data != null) {
        final distanceKm = (data['distanceKm'] as num?)?.toDouble() ?? 0.0;
        final durationMinutes = (data['durationMinutes'] as num?)?.toInt() ?? 1;
        final provider = data['provider'] as String? ?? 'OSRM';

        final geometry = data['geometry'] as Map<String, dynamic>?;
        final rawCoords = geometry?['coordinates'] as List<dynamic>? ?? [];

        final coordinates = <LatLng>[];
        for (final coord in rawCoords) {
          if (coord is List && coord.length >= 2) {
            // GeoJSON coordinates are in [longitude, latitude] order
            final lng = (coord[0] as num).toDouble();
            final lat = (coord[1] as num).toDouble();
            coordinates.add(LatLng(lat, lng));
          }
        }

        if (coordinates.isNotEmpty) {
          return RouteData(
            distanceKm: distanceKm,
            durationMinutes: durationMinutes,
            coordinates: coordinates,
            provider: provider,
          );
        }
      }
    } catch (_) {
      // Fallback to local geometric route calculation if offline
    }

    return _calculateFallbackRoute(originLat, originLng, destLat, destLng);
  }

  /// Deterministic local geometric fallback route
  static RouteData _calculateFallbackRoute(
    double originLat,
    double originLng,
    double destLat,
    double destLng,
  ) {
    final directDistance = DistanceUtil.calculateDistance(originLat, originLng, destLat, destLng);
    final roadDistance = directDistance * 1.25;
    final duration = (roadDistance / 30.0 * 60).round().clamp(2, 180);

    final coordinates = <LatLng>[];
    const steps = 8;
    for (int i = 0; i <= steps; i++) {
      final fraction = i / steps;
      final lat = originLat + (destLat - originLat) * fraction;
      final lng = originLng + (destLng - originLng) * fraction;
      coordinates.add(LatLng(lat, lng));
    }

    return RouteData(
      distanceKm: roadDistance,
      durationMinutes: duration,
      coordinates: coordinates,
      provider: 'RoadRescue-LocalFallback',
    );
  }
}
