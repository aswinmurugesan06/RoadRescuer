import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore-backed profile storage for the RoadRescue mobile app.
///
/// Profiles live in the `users/{uid}` collection, where `uid` is the Firebase
/// Authentication user id. This is the "database" half of the Firebase
/// serverless backend: authentication is handled by Firebase Auth, and the
/// application document is stored in Cloud Firestore.
///
/// The security rules for this collection are in `firebase/firestore.rules`.
class FirestoreProfileService {
  FirestoreProfileService._();

  static final FirestoreProfileService instance = FirestoreProfileService._();

  static const String collectionName = 'users';

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection(collectionName).doc(uid);

  /// Returns the profile for [uid], or null if it does not exist yet.
  Future<Map<String, dynamic>?> getProfile(String uid) async {
    final snapshot = await _doc(uid).get();
    if (!snapshot.exists) return null;
    return _withUid(uid, snapshot.data());
  }

  /// Creates or updates a profile. The role of an existing profile is kept so
  /// that an email sign-in cannot silently downgrade a provider to customer.
  Future<Map<String, dynamic>> saveProfile({
    required String uid,
    required String name,
    required String mobile,
    String? email,
    required String role,
    String? providerCategory,
    String? garageName,
  }) async {
    final ref = _doc(uid);
    final existing = await ref.get();
    final now = FieldValue.serverTimestamp();

    final resolvedRole =
        (existing.data()?['role'] as String?) ?? role.toUpperCase();

    final data = <String, dynamic>{
      'uid': uid,
      'name': name,
      'mobile': mobile,
      'role': resolvedRole,
      'updatedAt': now,
    };
    if (email != null && email.isNotEmpty) data['email'] = email;
    if (providerCategory != null && providerCategory.isNotEmpty) {
      data['providerCategory'] = providerCategory.toUpperCase();
      data['category'] = providerCategory.toUpperCase();
    }
    if (garageName != null && garageName.isNotEmpty) {
      data['garageName'] = garageName;
    }
    if (!existing.exists) {
      data['createdAt'] = now;
      data['isVerified'] = false;
      data['isActive'] = true;
      if (resolvedRole == 'PROVIDER') {
        data['verificationStatus'] = 'APPROVED';
        data['availability'] = 'OFFLINE';
        data['serviceRadiusKm'] = 25.0;
        data['rating'] = 5.0;
        data['ratingCount'] = 0;
        data['totalJobs'] = 0;
      }
    }

    await ref.set(data, SetOptions(merge: true));
    return (await getProfile(uid))!;
  }

  /// Applies a partial update to an existing profile.
  Future<Map<String, dynamic>?> updateProfile(
    String uid,
    Map<String, dynamic> patch,
  ) async {
    final ref = _doc(uid);
    final existing = await ref.get();
    if (!existing.exists) return null;

    final data = <String, dynamic>{
      ...patch,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    // Identity fields are owned by the backend / document id.
    data.remove('uid');
    data.remove('createdAt');

    if (data['role'] is String) {
      data['role'] = (data['role'] as String).toUpperCase();
    }
    if (data['providerCategory'] is String) {
      data['providerCategory'] =
          (data['providerCategory'] as String).toUpperCase();
    }

    await ref.set(data, SetOptions(merge: true));
    return getProfile(uid);
  }

  Future<void> deleteProfile(String uid) => _doc(uid).delete();

  Map<String, dynamic> _withUid(String uid, Map<String, dynamic>? data) =>
      <String, dynamic>{'uid': uid, ...?data};
}
