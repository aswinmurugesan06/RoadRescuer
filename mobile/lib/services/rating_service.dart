import '../models/rating_model.dart';
import 'api_client.dart';

/// Flutter service for submitting and viewing service ratings and reviews.
class RatingService {
  /// Submit a 1-5 star rating and optional written review for a completed service request.
  static Future<RatingModel> submitRating({
    required String requestId,
    required int score,
    String? review,
  }) async {
    final res = await ApiClient.post(
      '/ratings',
      {
        'requestId': requestId,
        'score': score,
        if (review != null && review.trim().isNotEmpty)
          'review': review.trim(),
      },
    );
    final data = res['data'] as Map<String, dynamic>;
    return RatingModel.fromJson(data);
  }

  /// Get rating submitted for a specific service request.
  /// Returns null if not rated yet.
  static Future<RatingModel?> getRatingByRequestId(String requestId) async {
    try {
      final res = await ApiClient.get('/ratings/request/$requestId');
      final data = res['data'] as Map<String, dynamic>?;
      return data != null ? RatingModel.fromJson(data) : null;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Get ratings list for a provider.
  static Future<Map<String, dynamic>> getProviderRatings(String providerId) async {
    final res = await ApiClient.get('/ratings/provider/$providerId');
    final data = res['data'] as Map<String, dynamic>? ?? {};
    final rawRatings = data['ratings'] as List<dynamic>? ?? [];
    final ratings = rawRatings
        .map((e) => RatingModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final summary = data['summary'] as Map<String, dynamic>? ?? {};

    return {
      'ratings': ratings,
      'averageRating': (summary['averageRating'] as num?)?.toDouble() ?? 5.0,
      'totalRatings': (summary['totalRatings'] as num?)?.toInt() ?? 0,
    };
  }
}
