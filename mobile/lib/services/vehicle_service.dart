import '../models/vehicle_model.dart';
import 'api_client.dart';

/// Handles all vehicle-related API calls.
class VehicleService {
  static const _path = '/vehicles';

  /// Fetch all vehicles belonging to the authenticated customer.
  static Future<List<VehicleModel>> getMyVehicles() async {
    final response = await ApiClient.get(_path);
    final data = response['data'] as List<dynamic>;
    return data
        .cast<Map<String, dynamic>>()
        .map(VehicleModel.fromJson)
        .toList();
  }

  /// Get a single vehicle by ID.
  static Future<VehicleModel> getVehicleById(String vehicleId) async {
    final response = await ApiClient.get('$_path/$vehicleId');
    return VehicleModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// Add a new vehicle.
  static Future<VehicleModel> addVehicle({
    required String type,
    required String manufacturer,
    required String model,
    required String plateNumber,
    String? year,
    String? color,
    bool isDefault = false,
  }) async {
    final response = await ApiClient.post(_path, {
      'type': type,
      'manufacturer': manufacturer,
      'model': model,
      'plateNumber': plateNumber,
      if (year != null && year.isNotEmpty) 'year': year,
      if (color != null && color.isNotEmpty) 'color': color,
      'isDefault': isDefault,
    });
    return VehicleModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// Update an existing vehicle (partial update).
  static Future<VehicleModel> updateVehicle(
    String vehicleId, {
    String? type,
    String? manufacturer,
    String? model,
    String? plateNumber,
    String? year,
    String? color,
    bool? isDefault,
  }) async {
    final body = <String, dynamic>{};
    if (type != null) body['type'] = type;
    if (manufacturer != null) body['manufacturer'] = manufacturer;
    if (model != null) body['model'] = model;
    if (plateNumber != null) body['plateNumber'] = plateNumber;
    if (year != null) body['year'] = year;
    if (color != null) body['color'] = color;
    if (isDefault != null) body['isDefault'] = isDefault;

    final response = await ApiClient.put('$_path/$vehicleId', body);
    return VehicleModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// Delete a vehicle.
  static Future<void> deleteVehicle(String vehicleId) async {
    await ApiClient.delete('$_path/$vehicleId');
  }

  /// Set a vehicle as the customer's default.
  static Future<VehicleModel> setDefaultVehicle(String vehicleId) async {
    final response = await ApiClient.patch('$_path/$vehicleId/set-default');
    return VehicleModel.fromJson(response['data'] as Map<String, dynamic>);
  }
}
