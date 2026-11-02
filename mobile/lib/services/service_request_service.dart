import '../models/service_request_model.dart';
import 'api_client.dart';

/// Service class handling all Service Request API operations for RoadRescue.
class ServiceRequestService {
  static const _path = '/service-requests';

  /// POST /api/service-requests — Create a new roadside assistance request.
  static Future<ServiceRequestModel> createRequest({
    required String serviceType,
    required String problemDescription,
    required double customerLatitude,
    required double customerLongitude,
    String? customerAddress,
    String? vehicleId,
    String? vehiclePlate,
    String? vehicleModel,
    String? vehicleType,
    String? category,
    double? estimatedAmount,
    String? pricingConfigId,
    Map<String, dynamic>? estimateBreakdown,
  }) async {
    final body = <String, dynamic>{
      'serviceType': serviceType,
      'problemDescription': problemDescription,
      'customerLatitude': customerLatitude,
      'customerLongitude': customerLongitude,
    };

    if (customerAddress != null && customerAddress.isNotEmpty) {
      body['customerAddress'] = customerAddress;
    }
    if (vehicleId != null && vehicleId.isNotEmpty) {
      body['vehicleId'] = vehicleId;
    }
    if (vehiclePlate != null && vehiclePlate.isNotEmpty) {
      body['vehiclePlate'] = vehiclePlate;
    }
    if (vehicleModel != null && vehicleModel.isNotEmpty) {
      body['vehicleModel'] = vehicleModel;
    }
    if (vehicleType != null && vehicleType.isNotEmpty) {
      body['vehicleType'] = vehicleType;
    }
    if (category != null && category.isNotEmpty) {
      body['category'] = category;
    }
    if (estimatedAmount != null) {
      body['estimatedAmount'] = estimatedAmount;
    }
    if (pricingConfigId != null && pricingConfigId.isNotEmpty) {
      body['pricingConfigId'] = pricingConfigId;
    }
    if (estimateBreakdown != null) {
      body['estimateBreakdown'] = estimateBreakdown;
    }

    final response = await ApiClient.post(_path, body);
    final data = response['data'] as Map<String, dynamic>;
    return ServiceRequestModel.fromJson(data);
  }

  /// GET /api/service-requests/my-requests — Customer's request history.
  static Future<List<ServiceRequestModel>> getMyRequests() async {
    final response = await ApiClient.get('$_path/my-requests');
    final data = response['data'] as List<dynamic>;
    return data
        .map((item) => ServiceRequestModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/service-requests/available — Available requests for approved/available provider.
  static Future<List<ServiceRequestModel>> getAvailableRequests() async {
    final response = await ApiClient.get('$_path/available');
    final data = response['data'] as List<dynamic>;
    return data
        .map((item) => ServiceRequestModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// PATCH /api/service-requests/:id/accept — Provider accepts a pending request.
  static Future<ServiceRequestModel> acceptRequest(String requestId) async {
    final response = await ApiClient.patch('$_path/$requestId/accept');
    final data = response['data'] as Map<String, dynamic>;
    return ServiceRequestModel.fromJson(data);
  }

  /// GET /api/service-requests/:id — View single request with authorized details.
  static Future<ServiceRequestModel> getRequestById(String requestId) async {
    final response = await ApiClient.get('$_path/$requestId');
    final data = response['data'] as Map<String, dynamic>;
    return ServiceRequestModel.fromJson(data);
  }

  /// PATCH /api/service-requests/:id/cancel — Customer or provider cancels request.
  static Future<ServiceRequestModel> cancelRequest(String requestId, {String? reason}) async {
    final response = await ApiClient.patch(
      '$_path/$requestId/cancel',
      body: reason != null ? {'cancellationReason': reason} : null,
    );
    final data = response['data'] as Map<String, dynamic>;
    return ServiceRequestModel.fromJson(data);
  }

  /// PATCH /api/service-requests/:id/status — Update status across lifecycle.
  static Future<ServiceRequestModel> updateStatus(String requestId, String status) async {
    final response = await ApiClient.patch(
      '$_path/$requestId/status',
      body: {'status': status},
    );
    final data = response['data'] as Map<String, dynamic>;
    return ServiceRequestModel.fromJson(data);
  }

  /// GET /api/service-requests/:id/discover — Discover and rank nearby eligible providers.
  static Future<Map<String, dynamic>> discoverNearbyProviders(
    String requestId, {
    double? radiusKm,
    int? limit,
  }) async {
    final queryParams = <String, String>{};
    if (radiusKm != null) queryParams['radiusKm'] = radiusKm.toString();
    if (limit != null) queryParams['limit'] = limit.toString();

    final queryString = queryParams.isNotEmpty
        ? '?${queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')}'
        : '';

    final response = await ApiClient.get('$_path/$requestId/discover$queryString');
    return response['data'] as Map<String, dynamic>;
  }

  /// POST /api/service-requests/:id/dispatch — Start automatic sequential dispatch.
  static Future<Map<String, dynamic>> triggerDispatch(
    String requestId, {
    double? radiusKm,
  }) async {
    final body = <String, dynamic>{};
    if (radiusKm != null) body['radiusKm'] = radiusKm;

    final response = await ApiClient.post('$_path/$requestId/dispatch', body);
    return response['data'] as Map<String, dynamic>;
  }

  /// PATCH /api/service-requests/:id/reject — Provider rejects a dispatched request.
  static Future<Map<String, dynamic>> rejectRequest(
    String requestId, {
    String? reason,
  }) async {
    final body = <String, dynamic>{};
    if (reason != null && reason.isNotEmpty) body['reason'] = reason;

    final response = await ApiClient.patch('$_path/$requestId/reject', body: body);
    return response['data'] as Map<String, dynamic>;
  }
}

