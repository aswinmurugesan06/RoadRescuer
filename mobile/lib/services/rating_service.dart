import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/rating_model.dart';
import 'firebase/firestore_helpers.dart';

/// Firestore-backed ratings and provider reputation.
class RatingService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Submit a 1-5 star rating for a completed request.
  static Future<RatingModel> submitRating({
    required String requestId,
    required int score,
    String? review,
  }) async {
    final uid = currentUid;
    final customer = await currentProfileJson();
    final requestDoc =
        await _db.collection('serviceRequests').doc(requestId).get();
    if (!requestDoc.exists) throw notFound('Service request');
    final request = requestDoc.data() ?? <String, dynamic>{};

    final providerId = request['providerId'] as String? ?? '';
    if (providerId.isEmpty) {
      throw notFound('Assigned provider');
    }
    final provider = await userJson(providerId);

    final ratingRef = _db.collection('ratings').doc();
    final providerRef = _db.collection('users').doc(providerId);
    final now = FieldValue.serverTimestamp();

    late Map<String, dynamic> ratingData;
    await _db.runTransaction((transaction) async {
      final providerSnapshot = await transaction.get(providerRef);
      final providerData = providerSnapshot.data() ?? <String, dynamic>{};
      final previousCount =
          (providerData['ratingCount'] as num?)?.toInt() ?? 0;
      final previousRating =
          (providerData['rating'] as num?)?.toDouble() ?? score.toDouble();
      final newCount = previousCount + 1;
      final newRating = previousCount == 0
          ? score.toDouble()
          : ((previousRating * previousCount) + score) / newCount;

      ratingData = {
        'requestId': requestId,
        'customerId': uid,
        'providerId': providerId,
        'score': score,
        if (review != null && review.trim().isNotEmpty)
          'review': review.trim(),
        'customer': {
          'id': uid,
          'name': customer?['name'] ?? request['customerName'] ?? 'Customer',
          'mobile': customer?['mobile'] ?? request['customerMobile'] ?? '',
        },
        'provider': {
          'id': providerId,
          'name': provider?['name'] ?? request['providerName'] ?? 'Provider',
          'mobile': provider?['mobile'] ?? request['providerMobile'] ?? '',
        },
        'createdAt': now,
        'updatedAt': now,
      };

      transaction.set(ratingRef, ratingData);
      transaction.update(providerRef, {
        'rating': newRating,
        'ratingCount': newCount,
        'updatedAt': now,
      });
    });

    final created = await ratingRef.get();
    final json = firestoreDocToJson(created);
    final providerSnapshot = await providerRef.get();
    final providerData = providerSnapshot.data() ?? <String, dynamic>{};
    json['providerAverageRating'] =
        (providerData['rating'] as num?)?.toDouble();
    json['providerTotalRatings'] =
        (providerData['ratingCount'] as num?)?.toInt();
    return RatingModel.fromJson(json);
  }

  /// Get the rating for a specific request, or null if not rated yet.
  static Future<RatingModel?> getRatingByRequestId(String requestId) async {
    final snapshot = await _db
        .collection('ratings')
        .where('requestId', isEqualTo: requestId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return RatingModel.fromJson(firestoreQueryDocToJson(snapshot.docs.first));
  }

  /// Get ratings for a provider with a summary.
  static Future<Map<String, dynamic>> getProviderRatings(
    String providerId,
  ) async {
    final snapshot = await _db
        .collection('ratings')
        .where('providerId', isEqualTo: providerId)
        .limit(200)
        .get();

    final ratings = snapshot.docs
        .map(firestoreQueryDocToJson)
        .map(RatingModel.fromJson)
        .toList();

    final total = ratings.length;
    final average = total == 0
        ? 5.0
        : ratings.fold<double>(0, (scoreSum, rating) => scoreSum + rating.score) /
            total;

    return {
      'ratings': ratings,
      'averageRating': average,
      'totalRatings': total,
    };
  }
}
