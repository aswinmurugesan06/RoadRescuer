class AdminStatsModel {
  final int totalCustomers;
  final int totalProviders;
  final int pendingVerifications;
  final int approvedProviders;
  final int activeRequests;
  final int completedRequests;
  final int cancelledRequests;
  final double totalRevenue;
  final double averageRating;

  const AdminStatsModel({
    required this.totalCustomers,
    required this.totalProviders,
    required this.pendingVerifications,
    required this.approvedProviders,
    required this.activeRequests,
    required this.completedRequests,
    required this.cancelledRequests,
    required this.totalRevenue,
    required this.averageRating,
  });

  factory AdminStatsModel.fromJson(Map<String, dynamic> json) {
    return AdminStatsModel(
      totalCustomers: (json['totalCustomers'] as num?)?.toInt() ?? 0,
      totalProviders: (json['totalProviders'] as num?)?.toInt() ?? 0,
      pendingVerifications: (json['pendingVerifications'] as num?)?.toInt() ?? 0,
      approvedProviders: (json['approvedProviders'] as num?)?.toInt() ?? 0,
      activeRequests: (json['activeRequests'] as num?)?.toInt() ?? 0,
      completedRequests: (json['completedRequests'] as num?)?.toInt() ?? 0,
      cancelledRequests: (json['cancelledRequests'] as num?)?.toInt() ?? 0,
      totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 5.0,
    );
  }
}
