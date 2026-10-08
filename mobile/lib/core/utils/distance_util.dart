import 'dart:math' as math;

/// Utility class for geographic distance calculation and formatting using the Haversine formula.
class DistanceUtil {
  DistanceUtil._();

  /// Earth radius in kilometers.
  static const double earthRadiusKm = 6371.0;

  /// Calculates the great-circle distance between two geographic coordinates in kilometers.
  ///
  /// Returns distance in kilometers (km).
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final lat1Rad = _toRadians(lat1);
    final lat2Rad = _toRadians(lat2);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) * math.sin(dLon / 2) * math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusKm * c;
  }

  /// Converts degrees to radians.
  static double _toRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }

  /// Formats a distance in kilometers into a human-readable string.
  ///
  /// Examples:
  /// - 0.05 km -> "50 m"
  /// - 0.75 km -> "750 m"
  /// - 3.42 km -> "3.4 km"
  /// - 25.0 km -> "25.0 km"
  static String formatDistance(double? distanceKm) {
    if (distanceKm == null || distanceKm.isNaN || distanceKm.isInfinite) {
      return '-- km';
    }

    if (distanceKm < 0.1) {
      final meters = (distanceKm * 1000).round();
      return '$meters m';
    }

    if (distanceKm < 1.0) {
      final meters = (distanceKm * 1000).round();
      return '$meters m';
    }

    return '${distanceKm.toStringAsFixed(1)} km';
  }

  /// Formats distance between two points directly.
  static String formatBetween({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final dist = calculateDistance(lat1, lon1, lat2, lon2);
    return formatDistance(dist);
  }

  /// Rough ETA string assuming 30 km/h average travel speed.
  /// Examples: 0.5 km -> "1 min", 15 km -> "30 min"
  static String etaMinutes(double distanceKm) {
    if (distanceKm <= 0) return '--';
    final mins = (distanceKm / 30.0 * 60).round();
    if (mins < 1) return '< 1 min';
    return '$mins min';
  }
}
