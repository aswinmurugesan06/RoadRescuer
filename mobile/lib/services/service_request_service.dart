import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils/distance_util.dart';
import '../models/service_request_model.dart';
import 'api_client.dart';
import 'firebase/firestore_helpers.dart';

/// Firestore-backed service request lifecycle.
///
/// Requests live in the top-level `serviceRequests` collection. Customer and
/// provider names are denormalized onto each request so lists can render
/// without extra reads.
class ServiceRequestService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('serviceRequests');

  /// Create a new roadside assistance request.
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
  }) async {
    final uid = currentUid;
    final profile = await currentProfileJson();
    final doc = _collection.doc();
    final now = FieldValue.serverTimestamp();
    final servicePin = _generateServicePin();

    await doc.set({
      'customerId': uid,
      'customerName': profile?['name'] ?? 'Customer',
      'customerMobile': profile?['mobile'] ?? '',
      'providerId': null,
      'providerName': null,
      'providerMobile': null,
      'category': _normalizeCategory(category ?? serviceType),
      'serviceType': serviceType,
      'problemDescription': problemDescription,
      'status': 'PENDING',
      'servicePin': servicePin,
      'customerLatitude': customerLatitude,
      'customerLongitude': customerLongitude,
      if (customerAddress != null && customerAddress.isNotEmpty)
        'customerAddress': customerAddress,
      if (vehicleId != null && vehicleId.isNotEmpty) 'vehicleId': vehicleId,
      if (vehiclePlate != null && vehiclePlate.isNotEmpty)
        'vehiclePlate': vehiclePlate,
      if (vehicleModel != null && vehicleModel.isNotEmpty)
        'vehicleModel': vehicleModel,
      if (vehicleType != null && vehicleType.isNotEmpty)
        'vehicleType': vehicleType,
      if (estimatedAmount != null) 'estimatedAmount': estimatedAmount,
      'createdAt': now,
      'updatedAt': now,
    });

    final created = await doc.get();
    return ServiceRequestModel.fromJson(firestoreDocToJson(created));
  }

  /// Customer's request history.
  static Future<List<ServiceRequestModel>> getMyRequests() async {
    final uid = currentUid;
    final snapshot = await _collection
        .where('customerId', isEqualTo: uid)
        .limit(100)
        .get();
    final requests = snapshot.docs
        .map(firestoreQueryDocToJson)
        .map(ServiceRequestModel.fromJson)
        .toList();
    requests.sort((a, b) => b.date.compareTo(a.date));
    return requests;
  }

  /// Available requests for an online provider.
  static Future<List<ServiceRequestModel>> getAvailableRequests() async {
    final profile = await currentProfileJson();
    final snapshot = await _collection
        .where('status', whereIn: const ['PENDING', 'SEARCHING'])
        .limit(100)
        .get();

    final providerCategory =
        (profile?['providerCategory'] ?? profile?['category']) as String?;
    final normalizedCategory = providerCategory == null
        ? null
        : _normalizeCategory(providerCategory);

    final requests = snapshot.docs
        .map(firestoreQueryDocToJson)
        .where((json) {
          final providerId = json['providerId'];
          if (providerId != null && (providerId as String).isNotEmpty) {
            return false;
          }
          if (normalizedCategory == null) return true;
          final category = _normalizeCategory(json['category'] as String? ?? '');
          return category == normalizedCategory;
        })
        .map(ServiceRequestModel.fromJson)
        .toList();

    requests.sort((a, b) => b.date.compareTo(a.date));
    return requests;
  }

  /// Provider accepts a pending request.
  static Future<ServiceRequestModel> acceptRequest(String requestId) async {
    final uid = currentUid;
    final profile = await currentProfileJson();
    final doc = _collection.doc(requestId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(doc);
      if (!snapshot.exists) throw notFound('Service request');
      final status = (snapshot.data()?['status'] as String? ?? '').toUpperCase();
      if (status != 'PENDING' && status != 'SEARCHING') {
        throw const ApiException(
          statusCode: 409,
          message: 'This request has already been accepted or closed.',
        );
      }

      transaction.update(doc, {
        'providerId': uid,
        'providerName': profile?['name'] ?? 'Service Provider',
        'providerMobile': profile?['mobile'] ?? '',
        'providerCategory':
            profile?['providerCategory'] ?? profile?['category'],
        'status': 'ACCEPTED',
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(_db.collection('users').doc(uid), {
        'availability': 'BUSY',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    return getRequestById(requestId);
  }

  /// View a single request.
  static Future<ServiceRequestModel> getRequestById(String requestId) async {
    final doc = await _collection.doc(requestId).get();
    if (!doc.exists) throw notFound('Service request');
    return ServiceRequestModel.fromJson(firestoreDocToJson(doc));
  }

  /// Cancel a request as customer or assigned provider.
  static Future<ServiceRequestModel> cancelRequest(
    String requestId, {
    String? reason,
  }) async {
    final doc = _collection.doc(requestId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(doc);
      if (!snapshot.exists) throw notFound('Service request');
      final data = snapshot.data() ?? <String, dynamic>{};
      final providerId = data['providerId'] as String?;

      transaction.update(doc, {
        'status': 'CANCELLED',
        if (reason != null && reason.isNotEmpty) 'cancellationReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (providerId != null && providerId.isNotEmpty) {
        transaction.update(_db.collection('users').doc(providerId), {
          'availability': 'AVAILABLE',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });

    return getRequestById(requestId);
  }

  /// Update the lifecycle status.
  static Future<ServiceRequestModel> updateStatus(
    String requestId,
    String status,
  ) async {
    final normalized = status.toUpperCase();
    final doc = _collection.doc(requestId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(doc);
      if (!snapshot.exists) throw notFound('Service request');
      final data = snapshot.data() ?? <String, dynamic>{};
      final providerId = data['providerId'] as String?;
      final previousStatus =
          (data['status'] as String?)?.toUpperCase() ?? '';

      final updates = <String, dynamic>{
        'status': normalized,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (normalized == 'COMPLETED') {
        updates['completedAt'] = FieldValue.serverTimestamp();
      }
      transaction.update(doc, updates);

      if (providerId != null && providerId.isNotEmpty) {
        final providerRef = _db.collection('users').doc(providerId);
        if (normalized == 'COMPLETED') {
          // Only count the job once, even if completion is saved twice.
          transaction.update(providerRef, {
            'availability': 'AVAILABLE',
            if (previousStatus != 'COMPLETED')
              'totalJobs': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else if (normalized == 'ACCEPTED' || normalized == 'IN_SERVICE') {
          transaction.update(providerRef, {
            'availability': 'BUSY',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    });

    return getRequestById(requestId);
  }

  /// Discover and rank nearby eligible providers for a request.
  static Future<Map<String, dynamic>> discoverNearbyProviders(
    String requestId, {
    double? radiusKm,
    int? limit,
  }) async {
    final request = await getRequestById(requestId);
    final snapshot = await _db
        .collection('users')
        .where('role', isEqualTo: 'PROVIDER')
        .where('availability', isEqualTo: 'AVAILABLE')
        .get();

    final maxRadius = radiusKm ?? 25.0;
    final results = <Map<String, dynamic>>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final lat = (data['latitude'] as num?)?.toDouble();
      final lng = (data['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      if (request.customerLatitude == null || request.customerLongitude == null) {
        continue;
      }

      final distance = DistanceUtil.calculateDistance(
        request.customerLatitude!,
        request.customerLongitude!,
        lat,
        lng,
      );
      if (distance > maxRadius) continue;

      results.add({
        'id': doc.id,
        'name': data['name'] ?? 'Service Provider',
        'mobile': data['mobile'] ?? '',
        'garageName': data['garageName'] ?? 'Independent Specialist',
        'category': data['providerCategory'] ?? data['category'] ?? 'MECHANIC',
        'rating': (data['rating'] as num?)?.toDouble() ?? 5.0,
        'totalJobs': (data['totalJobs'] as num?)?.toInt() ?? 0,
        'latitude': lat,
        'longitude': lng,
        'distanceKm': double.parse(distance.toStringAsFixed(2)),
        'etaMinutes': DistanceUtil.etaMinutes(distance),
      });
    }

    results.sort(
      (a, b) => (a['distanceKm'] as num).compareTo(b['distanceKm'] as num),
    );

    if (limit != null && results.length > limit) {
      results.removeRange(limit, results.length);
    }

    return {
      'request': _requestToJson(request),
      'providers': results,
      'radiusKm': maxRadius,
    };
  }

  /// Move a request into the searching state.
  static Future<Map<String, dynamic>> triggerDispatch(
    String requestId, {
    double? radiusKm,
  }) async {
    final request = await updateStatus(requestId, 'SEARCHING');
    return {
      'request': _requestToJson(request),
      'status': 'SEARCHING',
      'radiusKm': radiusKm ?? 25.0,
    };
  }

  /// Provider rejects a dispatched request.
  static Future<Map<String, dynamic>> rejectRequest(
    String requestId, {
    String? reason,
  }) async {
    final uid = currentUid;
    final doc = _collection.doc(requestId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(doc);
      if (!snapshot.exists) throw notFound('Service request');
      final data = snapshot.data() ?? <String, dynamic>{};

      final updates = <String, dynamic>{
        'rejectedBy': FieldValue.arrayUnion([uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (data['providerId'] == uid) {
        updates['providerId'] = null;
        updates['providerName'] = null;
        updates['providerMobile'] = null;
        updates['status'] = 'PENDING';
      }
      transaction.update(doc, updates);
    });

    return {
      'requestId': requestId,
      'rejected': true,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    };
  }

  static Map<String, dynamic> _requestToJson(ServiceRequestModel request) {
    return {
      'id': request.id,
      'vehicleId': request.vehicleId,
      'vehiclePlate': request.vehiclePlate,
      'vehicleModel': request.vehicleModel,
      'vehicleType': request.vehicleType,
      'serviceType': request.serviceType,
      'problemDescription': request.problem,
      'status': request.status.name.toUpperCase(),
      'providerId': request.providerId,
      'providerName': request.providerName,
      'providerMobile': request.providerMobile,
      'customerName': request.customerName,
      'customerMobile': request.customerMobile,
      'customerLatitude': request.customerLatitude,
      'customerLongitude': request.customerLongitude,
      'customerAddress': request.customerAddress,
      'category': request.category,
      'estimatedAmount': request.totalAmount,
      'cancellationReason': request.cancellationReason,
      'createdAt': request.date.toIso8601String(),
    };
  }

  /// Generates the 4-digit code the customer shares with the technician.
  static String _generateServicePin() {
    final pin = Random().nextInt(9000) + 1000;
    return pin.toString();
  }

  static String _normalizeCategory(String value) {
    final upper = value.trim().toUpperCase();
    switch (upper) {
      case 'MECHANIC':
      case 'MECHANICAL REPAIR':
        return 'MECHANIC';
      case 'PUNCTURE':
      case 'TYRE & PUNCTURE SERVICE':
        return 'PUNCTURE';
      case 'TOW':
      case 'TOW_TRUCK':
      case 'TOW TRUCK / RECOVERY':
        return 'TOW_TRUCK';
      case 'BATTERY':
      case 'BATTERY JUMP-START':
        return 'BATTERY';
      case 'FUEL':
      case 'EMERGENCY FUEL DELIVERY':
        return 'FUEL';
      default:
        return upper.isEmpty ? 'MECHANIC' : upper;
    }
  }
}
