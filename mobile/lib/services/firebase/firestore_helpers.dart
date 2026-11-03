import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../api_client.dart';

/// UID of the signed-in Firebase user.
///
/// Throws an [ApiException] so existing screens keep their error handling.
String get currentUid {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw const ApiException(
      statusCode: 401,
      message: 'Please sign in to continue.',
    );
  }
  return user.uid;
}

/// Converts Firestore documents into the JSON shape the app models expect.
///
/// - Timestamps become ISO-8601 strings.
/// - The document id is exposed as `id`.
Map<String, dynamic> firestoreDocToJson(
  DocumentSnapshot<Map<String, dynamic>> doc,
) {
  final normalized = normalizeFirestoreValue(doc.data() ?? <String, dynamic>{});
  final json = normalized is Map<String, dynamic>
      ? normalized
      : Map<String, dynamic>.from(normalized as Map);
  json['id'] = doc.id;
  return json;
}

/// Same as [firestoreDocToJson] but kept as a distinct helper for query
/// results (which are also document snapshots).
Map<String, dynamic> firestoreQueryDocToJson(
  DocumentSnapshot<Map<String, dynamic>> doc,
) {
  return firestoreDocToJson(doc);
}

/// Recursively converts Firestore values into JSON-safe values.
dynamic normalizeFirestoreValue(dynamic value) {
  if (value is Timestamp) return value.toDate().toIso8601String();
  if (value is DateTime) return value.toIso8601String();
  if (value is Map) {
    return value.map(
      (key, item) => MapEntry(key.toString(), normalizeFirestoreValue(item)),
    );
  }
  if (value is Iterable) {
    return value.map(normalizeFirestoreValue).toList();
  }
  return value;
}

/// Reads the signed-in user's Firestore profile, or null if it is missing.
Future<Map<String, dynamic>?> currentProfileJson() async {
  final uid = currentUid;
  final doc =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();
  if (!doc.exists) return null;
  return firestoreDocToJson(doc);
}

/// Reads another user's Firestore profile, or null if it is missing.
Future<Map<String, dynamic>?> userJson(String uid) async {
  final doc =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();
  if (!doc.exists) return null;
  return firestoreDocToJson(doc);
}

/// Normalizes a mobile number to the last 10 digits.
String normalizeMobile(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
}

/// Throws a friendly 404 when a document is missing.
ApiException notFound(String label) => ApiException(
      statusCode: 404,
      message: '$label was not found.',
    );
