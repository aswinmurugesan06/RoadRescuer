import '../models/admin_stats_model.dart';
import 'api_client.dart';

/// Flutter service for Admin portal operations.
class AdminService {
  /// Fetch platform-wide metrics.
  static Future<AdminStatsModel> getStats() async {
    final res = await ApiClient.get('/admin/stats');
    final data = res['data'] as Map<String, dynamic>;
    return AdminStatsModel.fromJson(data);
  }

  /// List providers with filtering.
  static Future<Map<String, dynamic>> listProviders({
    String? status,
    String? category,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      if (status != null && status.isNotEmpty) 'status': status,
      if (category != null && category.isNotEmpty) 'category': category,
      if (search != null && search.isNotEmpty) 'search': search,
    };
    final queryString = Uri(queryParameters: params).query;
    final res = await ApiClient.get('/admin/providers?$queryString');
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  /// Get detailed provider profile.
  static Future<Map<String, dynamic>> getProviderDetails(String providerId) async {
    final res = await ApiClient.get('/admin/providers/$providerId');
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  /// Update provider verification status (APPROVED, REJECTED, SUSPENDED).
  static Future<Map<String, dynamic>> updateProviderVerification(
    String providerId, {
    required String verificationStatus,
    String? reason,
  }) async {
    final res = await ApiClient.patch(
      '/admin/providers/$providerId/verification',
      body: {
        'verificationStatus': verificationStatus,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  /// List platform users.
  static Future<Map<String, dynamic>> listUsers({
    String? role,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      if (role != null && role.isNotEmpty) 'role': role,
      if (search != null && search.isNotEmpty) 'search': search,
    };
    final queryString = Uri(queryParameters: params).query;
    final res = await ApiClient.get('/admin/users?$queryString');
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  /// List platform service requests.
  static Future<Map<String, dynamic>> listServiceRequests({
    String? status,
    String? category,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      if (status != null && status.isNotEmpty) 'status': status,
      if (category != null && category.isNotEmpty) 'category': category,
      if (search != null && search.isNotEmpty) 'search': search,
    };
    final queryString = Uri(queryParameters: params).query;
    final res = await ApiClient.get('/admin/service-requests?$queryString');
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  /// List platform payments.
  static Future<Map<String, dynamic>> listPayments({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      if (status != null && status.isNotEmpty) 'status': status,
    };
    final queryString = Uri(queryParameters: params).query;
    final res = await ApiClient.get('/admin/payments?$queryString');
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  /// List platform ratings.
  static Future<Map<String, dynamic>> listRatings({
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    final queryString = Uri(queryParameters: params).query;
    final res = await ApiClient.get('/admin/ratings?$queryString');
    return res['data'] as Map<String, dynamic>? ?? {};
  }

  /// Delete a rating (moderation).
  static Future<Map<String, dynamic>> deleteRating(String ratingId) async {
    final res = await ApiClient.delete('/admin/ratings/$ratingId');
    return res['data'] as Map<String, dynamic>? ?? {};
  }
}
