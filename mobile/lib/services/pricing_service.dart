import '../models/pricing_estimate_model.dart';
import 'api_client.dart';

/// Service class handling Dynamic Cost Estimation API calls for RoadRescue.
class PricingService {
  static const String _path = '/pricing/estimate';

  /// Helper to convert UI service type strings (e.g., 'Mechanic', 'Tow')
  /// to backend ProviderCategory enum values ('MECHANIC', 'TOW_TRUCK', etc.).
  static String normalizeCategory(String serviceType) {
    final upper = serviceType.trim().toUpperCase();
    if (upper == 'TOW' || upper == 'TOW TRUCK') return 'TOW_TRUCK';
    if (upper == 'TYRE & PUNCTURE' || upper == 'PUNCTURE') return 'PUNCTURE';
    if (upper == 'BATTERY JUMP-START' || upper == 'BATTERY') return 'BATTERY';
    if (upper == 'EMERGENCY FUEL' || upper == 'FUEL') return 'FUEL';
    if (upper == 'MECHANICAL REPAIR' || upper == 'MECHANIC') return 'MECHANIC';
    return upper;
  }

  /// Request a dynamic cost estimate from backend.
  /// All pricing calculations occur on the backend and are never computed client-side.
  static Future<PricingEstimateModel> getEstimate({
    required String serviceType,
    String? problem,
    String? vehicleType,
    double? customerLatitude,
    double? customerLongitude,
    double? destinationLatitude,
    double? destinationLongitude,
    String? providerId,
  }) async {
    final body = <String, dynamic>{
      'category': normalizeCategory(serviceType),
    };

    if (problem != null && problem.trim().isNotEmpty) {
      body['problemCategory'] = problem.trim();
    }
    if (vehicleType != null && vehicleType.trim().isNotEmpty) {
      body['vehicleType'] = vehicleType.trim();
    }
    if (customerLatitude != null && customerLongitude != null) {
      body['customerLat'] = customerLatitude;
      body['customerLng'] = customerLongitude;
    }
    if (destinationLatitude != null && destinationLongitude != null) {
      body['destinationLat'] = destinationLatitude;
      body['destinationLng'] = destinationLongitude;
    }
    if (providerId != null && providerId.trim().isNotEmpty) {
      body['providerId'] = providerId.trim();
    }

    try {
      final response = await ApiClient.post(_path, body);
      final data = response['data'] as Map<String, dynamic>;
      return PricingEstimateModel.fromJson(data);
    } on ApiException catch (e) {
      // Preserve status code context for 404 (no active rule) vs other errors
      throw ApiException(
        statusCode: e.statusCode,
        message: e.message,
        errors: e.errors,
      );
    } catch (e) {
      throw ApiException(
        statusCode: 500,
        message: 'Failed to retrieve pricing estimate: ${e.toString()}',
      );
    }
  }
}
