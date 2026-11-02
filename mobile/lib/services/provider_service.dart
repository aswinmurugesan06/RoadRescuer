import '../models/provider_model.dart';
import '../models/service_request_model.dart';
import 'api_client.dart';

/// Handles all provider-management API calls for the authenticated provider.
class ProviderService {
  static const _path = '/providers';

  /// GET /api/providers/profile — Fetch provider's own full profile.
  static Future<ProviderAccountModel> getProfile() async {
    final response = await ApiClient.get('$_path/profile');
    return ProviderAccountModel.fromJson(
      response['data'] as Map<String, dynamic>,
    );
  }

  /// PATCH /api/providers/profile — Update garageName, businessAddress,
  /// serviceRadiusKm, or category.
  static Future<ProviderProfileData> updateProfile({
    String? garageName,
    String? businessAddress,
    double? serviceRadiusKm,
    String? category,
  }) async {
    final body = <String, dynamic>{};
    if (garageName != null) body['garageName'] = garageName;
    if (businessAddress != null) body['businessAddress'] = businessAddress;
    if (serviceRadiusKm != null) body['serviceRadiusKm'] = serviceRadiusKm;
    if (category != null) body['category'] = category;

    final response = await ApiClient.patch('$_path/profile', body: body);
    return ProviderProfileData.fromJson(
      response['data'] as Map<String, dynamic>,
    );
  }

  /// PATCH /api/providers/availability — Set OFFLINE or AVAILABLE.
  /// BUSY is managed automatically by the service-request workflow.
  /// [availability] must be 'OFFLINE' or 'AVAILABLE'.
  static Future<ProviderProfileData> setAvailability(String availability) async {
    final response = await ApiClient.patch(
      '$_path/availability',
      body: {'availability': availability},
    );
    return ProviderProfileData.fromJson(
      response['data'] as Map<String, dynamic>,
    );
  }

  /// PATCH /api/providers/me/location — Broadcast current GPS coordinates.
  static Future<ProviderProfileData> updateLocation({
    required double latitude,
    required double longitude,
  }) async {
    final response = await ApiClient.patch(
      '$_path/me/location',
      body: {'latitude': latitude, 'longitude': longitude},
    );
    return ProviderProfileData.fromJson(
      response['data'] as Map<String, dynamic>,
    );
  }

  /// GET /api/providers/my-requests — Fetch all service requests
  /// assigned to this provider.
  static Future<List<Map<String, dynamic>>> getMyRequests() async {
    final response = await ApiClient.get('$_path/my-requests');
    final data = response['data'] as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  /// GET /api/providers/history — Fetch completed job history for the authenticated provider.
  static Future<List<ServiceRequestModel>> getJobHistory() async {
    final response = await ApiClient.get('$_path/history');
    final data = response['data'] as List<dynamic>? ?? [];
    return data
        .map((json) => ServiceRequestModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/providers/earnings — Fetch calculated earnings, commission, and payment history.
  static Future<Map<String, dynamic>> getEarnings() async {
    final response = await ApiClient.get('$_path/earnings');
    return response['data'] as Map<String, dynamic>;
  }
}
