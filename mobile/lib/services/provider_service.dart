import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/provider_model.dart';
import 'api_client.dart';
import 'firebase/firestore_helpers.dart';

/// Firestore-backed provider profile and earnings service.
///
/// A provider is a normal `users/{uid}` document with `role == 'PROVIDER'`
/// plus provider-specific fields (`availability`, `latitude`, `rating`, ...).
class ProviderService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> get _userRef =>
      _db.collection('users').doc(currentUid);

  /// Fetch the authenticated provider's full profile.
  static Future<ProviderAccountModel> getProfile() async {
    final uid = currentUid;
    final doc = await _userRef.get();
    if (!doc.exists) throw notFound('Provider profile');
    final user = firestoreDocToJson(doc);
    return ProviderAccountModel.fromJson(_accountJson(user, uid));
  }

  /// Update garageName, businessAddress, serviceRadiusKm, or category.
  static Future<ProviderProfileData> updateProfile({
    String? garageName,
    String? businessAddress,
    double? serviceRadiusKm,
    String? category,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (garageName != null) updates['garageName'] = garageName;
    if (businessAddress != null) updates['businessAddress'] = businessAddress;
    if (serviceRadiusKm != null) updates['serviceRadiusKm'] = serviceRadiusKm;
    if (category != null && category.isNotEmpty) {
      final normalized = category.toUpperCase();
      updates['providerCategory'] = normalized;
      updates['category'] = normalized;
    }

    await _userRef.update(updates);
    return _profileFromUserDoc();
  }

  /// Set OFFLINE or AVAILABLE. BUSY is managed by the request workflow.
  static Future<ProviderProfileData> setAvailability(
    String availability,
  ) async {
    final normalized = availability.toUpperCase();
    final doc = await _userRef.get();
    if (!doc.exists) throw notFound('Provider profile');
    final data = doc.data() ?? <String, dynamic>{};

    if (normalized == 'AVAILABLE') {
      final status =
          (data['verificationStatus'] as String? ?? 'APPROVED').toUpperCase();
      if (status != 'APPROVED') {
        throw ApiException(
          statusCode: 403,
          message:
              'Cannot go online — your account is $status. Contact support for approval.',
        );
      }
    }

    await _userRef.update({
      'availability': normalized,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return _profileFromUserDoc();
  }

  /// Broadcast current GPS coordinates.
  static Future<ProviderProfileData> updateLocation({
    required double latitude,
    required double longitude,
  }) async {
    await _userRef.update({
      'latitude': latitude,
      'longitude': longitude,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return _profileFromUserDoc();
  }

  /// All service requests assigned to this provider.
  static Future<List<Map<String, dynamic>>> getMyRequests() async {
    final uid = currentUid;
    final snapshot = await _db
        .collection('serviceRequests')
        .where('providerId', isEqualTo: uid)
        .limit(100)
        .get();

    final requests = snapshot.docs.map(firestoreQueryDocToJson).toList();
    requests.sort((a, b) {
      final aDate = DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return requests;
  }

  /// Calculated earnings, commission, and recent settlements.
  static Future<Map<String, dynamic>> getEarnings() async {
    final uid = currentUid;
    final snapshot = await _db
        .collection('payments')
        .where('providerId', isEqualTo: uid)
        .limit(200)
        .get();

    final payments = snapshot.docs
        .map(firestoreQueryDocToJson)
        .where((payment) =>
            (payment['status'] as String? ?? '').toUpperCase() == 'COMPLETED')
        .toList();

    payments.sort((a, b) {
      final aDate = DateTime.tryParse(
              (a['paidAt'] ?? a['createdAt'])?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = DateTime.tryParse(
              (b['paidAt'] ?? b['createdAt'])?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    var gross = 0.0;
    for (final payment in payments) {
      gross += (payment['amount'] as num?)?.toDouble() ?? 0.0;
    }
    const commissionRate = 0.10;
    final commission = gross * commissionRate;
    final net = gross - commission;

    final recentPayments = payments.map((payment) {
      final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
      return <String, dynamic>{
        ...payment,
        'netAmount': amount * (1 - commissionRate),
      };
    }).toList();

    return {
      'grossServiceBilling': gross,
      'totalCompletedServices': payments.length,
      'platformCommission': commission,
      'netProviderEarnings': net,
      'recentPayments': recentPayments,
    };
  }

  static Future<ProviderProfileData> _profileFromUserDoc() async {
    final uid = currentUid;
    final doc = await _userRef.get();
    if (!doc.exists) throw notFound('Provider profile');
    final user = firestoreDocToJson(doc);
    return ProviderProfileData.fromJson(_providerProfileJson(user, uid));
  }

  static Map<String, dynamic> _accountJson(
    Map<String, dynamic> user,
    String uid,
  ) {
    return {
      'id': uid,
      'name': user['name'] ?? 'Service Provider',
      'email': user['email'] ?? '',
      'mobile': user['mobile'] ?? '',
      'role': user['role'] ?? 'PROVIDER',
      'isVerified': user['isVerified'] ?? false,
      'isActive': user['isActive'] ?? true,
      'createdAt': user['createdAt'] ?? DateTime.now().toIso8601String(),
      'providerProfile': _providerProfileJson(user, uid),
    };
  }

  static Map<String, dynamic> _providerProfileJson(
    Map<String, dynamic> user,
    String uid,
  ) {
    final now = DateTime.now().toIso8601String();
    return {
      'id': uid,
      'userId': uid,
      'category': user['providerCategory'] ?? user['category'] ?? 'MECHANIC',
      'verificationStatus': user['verificationStatus'] ?? 'APPROVED',
      'availability': user['availability'] ?? 'OFFLINE',
      'garageName': user['garageName'],
      'businessAddress': user['businessAddress'],
      'serviceRadiusKm': (user['serviceRadiusKm'] as num?)?.toDouble() ?? 25.0,
      'latitude': (user['latitude'] as num?)?.toDouble(),
      'longitude': (user['longitude'] as num?)?.toDouble(),
      'rating': (user['rating'] as num?)?.toDouble() ?? 5.0,
      'ratingCount': (user['ratingCount'] as num?)?.toInt() ?? 0,
      'totalJobs': (user['totalJobs'] as num?)?.toInt() ?? 0,
      'createdAt': user['createdAt'] ?? now,
      'updatedAt': user['updatedAt'] ?? now,
    };
  }
}
