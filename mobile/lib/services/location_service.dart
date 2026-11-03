import 'package:geolocator/geolocator.dart';

/// Custom exception thrown when GPS/Location services are disabled on the device.
class LocationServiceDisabledException implements Exception {
  final String message;
  const LocationServiceDisabledException([
    this.message = 'Location services are disabled. Please turn on GPS in your device settings.',
  ]);

  @override
  String toString() => message;
}

/// Custom exception thrown when foreground location permission is denied by user.
class LocationPermissionDeniedException implements Exception {
  final String message;
  const LocationPermissionDeniedException([
    this.message = 'Location permission was denied. Location access is required for roadside assistance.',
  ]);

  @override
  String toString() => message;
}

/// Custom exception thrown when location permission is permanently denied.
class LocationPermissionDeniedForeverException implements Exception {
  final String message;
  const LocationPermissionDeniedForeverException([
    this.message = 'Location permissions are permanently denied. Please enable them in App Settings.',
  ]);

  @override
  String toString() => message;
}

/// Encapsulates device GPS location state and coordinates.
class DeviceLocation {
  final double latitude;
  final double longitude;
  final double accuracy; // meters
  final double? altitude;
  final double? speed;
  final DateTime timestamp;

  const DeviceLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.altitude,
    this.speed,
    required this.timestamp,
  });

  factory DeviceLocation.fromPosition(Position position) {
    return DeviceLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      altitude: position.altitude,
      speed: position.speed,
      timestamp: position.timestamp,
    );
  }

  String get formattedCoordinates =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

  String get accuracyLabel => '±${accuracy.toStringAsFixed(1)}m';
}

/// Dedicated service for real device GPS location handling.
/// Restricts access to foreground location only.
class LocationService {
  /// Checks if device GPS / Location services are currently enabled.
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Checks current location permission status.
  static Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Requests foreground location permission from the user.
  static Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Opens the device app settings screen so user can grant denied-forever permissions.
  static Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Opens the device location settings so user can enable GPS if disabled.
  static Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Retrieves the real device GPS position with proper permission and service checks.
  /// Throws:
  ///  - [LocationServiceDisabledException] if GPS is turned off
  ///  - [LocationPermissionDeniedException] if user denies permission
  ///  - [LocationPermissionDeniedForeverException] if user permanently denies permission
  static Future<DeviceLocation> getCurrentLocation({
    LocationAccuracy desiredAccuracy = LocationAccuracy.high,
    Duration timeLimit = const Duration(seconds: 15),
  }) async {
    // 1. Check if location services are enabled on device
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }

    // 2. Check permission status
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationPermissionDeniedException();
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationPermissionDeniedForeverException();
    }

    // 3. Acquire current device position
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: desiredAccuracy,
        timeLimit: timeLimit,
      );
      return DeviceLocation.fromPosition(position);
    } catch (e) {
      // If accurate fix times out, attempt to get last known position
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        return DeviceLocation.fromPosition(lastKnown);
      }
      rethrow;
    }
  }

  /// Gets last known position cached by device, if any.
  static Future<DeviceLocation?> getLastKnownLocation() async {
    final pos = await Geolocator.getLastKnownPosition();
    if (pos == null) return null;
    return DeviceLocation.fromPosition(pos);
  }
}
