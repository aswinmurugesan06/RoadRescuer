import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/vehicle_model.dart';
import 'firebase/firestore_helpers.dart';

/// Firestore-backed vehicle storage.
///
/// Vehicles live at `users/{uid}/vehicles/{vehicleId}` so every customer can
/// only read and write their own garage.
class VehicleService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('users').doc(currentUid).collection('vehicles');

  /// Fetch all vehicles belonging to the authenticated customer.
  static Future<List<VehicleModel>> getMyVehicles() async {
    final snapshot = await _collection.get();
    final vehicles = snapshot.docs
        .map(firestoreQueryDocToJson)
        .map(VehicleModel.fromJson)
        .toList();
    vehicles.sort((a, b) {
      if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
      return a.displayName.compareTo(b.displayName);
    });
    return vehicles;
  }

  /// Get a single vehicle by ID.
  static Future<VehicleModel> getVehicleById(String vehicleId) async {
    final doc = await _collection.doc(vehicleId).get();
    if (!doc.exists) throw notFound('Vehicle');
    return VehicleModel.fromJson(firestoreDocToJson(doc));
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
    final doc = _collection.doc();
    final now = FieldValue.serverTimestamp();

    if (isDefault) {
      await _clearDefault();
    }

    await doc.set({
      'type': type,
      'manufacturer': manufacturer,
      'model': model,
      'plateNumber': plateNumber,
      if (year != null && year.isNotEmpty) 'year': year,
      if (color != null && color.isNotEmpty) 'color': color,
      'isDefault': isDefault,
      'createdAt': now,
      'updatedAt': now,
    });

    final created = await doc.get();
    return VehicleModel.fromJson(firestoreDocToJson(created));
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
    final doc = _collection.doc(vehicleId);
    final existing = await doc.get();
    if (!existing.exists) throw notFound('Vehicle');

    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (type != null) updates['type'] = type;
    if (manufacturer != null) updates['manufacturer'] = manufacturer;
    if (model != null) updates['model'] = model;
    if (plateNumber != null) updates['plateNumber'] = plateNumber;
    if (year != null) updates['year'] = year;
    if (color != null) updates['color'] = color;
    if (isDefault != null) updates['isDefault'] = isDefault;

    if (isDefault == true) {
      await _clearDefault(exceptId: vehicleId);
    }

    await doc.update(updates);
    final updated = await doc.get();
    return VehicleModel.fromJson(firestoreDocToJson(updated));
  }

  /// Delete a vehicle.
  static Future<void> deleteVehicle(String vehicleId) async {
    await _collection.doc(vehicleId).delete();
  }

  /// Set a vehicle as the customer's default.
  static Future<VehicleModel> setDefaultVehicle(String vehicleId) async {
    final doc = _collection.doc(vehicleId);
    final existing = await doc.get();
    if (!existing.exists) throw notFound('Vehicle');

    final batch = _db.batch();
    final all = await _collection.get();
    for (final item in all.docs) {
      batch.update(item.reference, {'isDefault': item.id == vehicleId});
    }
    batch.update(doc, {'updatedAt': FieldValue.serverTimestamp()});
    await batch.commit();

    final updated = await doc.get();
    return VehicleModel.fromJson(firestoreDocToJson(updated));
  }

  static Future<void> _clearDefault({String? exceptId}) async {
    final all = await _collection.where('isDefault', isEqualTo: true).get();
    if (all.docs.isEmpty) return;
    final batch = _db.batch();
    for (final item in all.docs) {
      if (item.id == exceptId) continue;
      batch.update(item.reference, {'isDefault': false});
    }
    await batch.commit();
  }
}
