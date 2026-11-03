import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';

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
///
/// Uses the public OSRM demo server directly (no RoadRescue backend) and
/// falls back to a deterministic local route when the network is unavailable.
class RoutingService {
  RoutingService._();

  static const String _osrmBase = 'https://router.project-osrm.org';

  /// Calculate route between origin and destination coordinates.
  static Future<RouteData> getDirections({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    try {
      final uri = Uri.parse(
        '$_osrmBase/route/v1/driving/$originLng,$originLat;$destLng,$destLat'
        '?overview=full&geometries=geojson',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = body['routes'] as List<dynamic>? ?? [];
        if (routes.isNotEmpty) {
          final route = routes.first as Map<String, dynamic>;
          final distanceKm =
              ((route['distance'] as num?)?.toDouble() ?? 0) / 1000.0;
          final durationMinutes =
              (((route['duration'] as num?)?.toDouble() ?? 0) / 60).round();
          final geometry = route['geometry'] as Map<String, dynamic>?;
          final rawCoords = geometry?['coordinates'] as List<dynamic>? ?? [];

          final coordinates = <LatLng>[];
          for (final coord in rawCoords) {
            if (coord is List && coord.length >= 2) {
              final lng = (coord[0] as num).toDouble();
              final lat = (coord[1] as num).toDouble();
              coordinates.add(LatLng(lat, lng));
            }
          }

          if (coordinates.isNotEmpty) {
            return RouteData(
              distanceKm: distanceKm,
              durationMinutes: durationMinutes.clamp(1, 600),
              coordinates: coordinates,
              provider: 'OSRM',
            );
          }
        }
      }
    } catch (_) {
      // Fall back to a local geometric route if offline.
    }

    return _calculateFallbackRoute(originLat, originLng, destLat, destLng);
  }

  /// Deterministic local geometric fallback route.
  static RouteData _calculateFallbackRoute(
    double originLat,
    double originLng,
    double destLat,
    double destLng,
  ) {
    final directDistance =
        DistanceUtil.calculateDistance(originLat, originLng, destLat, destLng);
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
