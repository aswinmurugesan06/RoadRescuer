class RatingModel {
  final String id;
  final String requestId;
  final String customerId;
  final String providerId;
  final int score;
  final String? review;
  final DateTime? createdAt;
  final String? customerName;
  final String? providerName;
  final double? providerAverageRating;
  final int? providerTotalRatings;

  const RatingModel({
    required this.id,
    required this.requestId,
    required this.customerId,
    required this.providerId,
    required this.score,
    this.review,
    this.createdAt,
    this.customerName,
    this.providerName,
    this.providerAverageRating,
    this.providerTotalRatings,
  });

  factory RatingModel.fromJson(Map<String, dynamic> json) {
    return RatingModel(
      id: json['id'] as String? ?? '',
      requestId: json['requestId'] as String? ?? '',
      customerId: json['customerId'] as String? ?? '',
      providerId: json['providerId'] as String? ?? '',
      score: (json['score'] as num?)?.toInt() ?? 5,
      review: json['review'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      customerName: json['customer'] != null && json['customer'] is Map
          ? (json['customer'] as Map<String, dynamic>)['name'] as String?
          : null,
      providerName: json['provider'] != null && json['provider'] is Map
          ? (json['provider'] as Map<String, dynamic>)['name'] as String?
          : null,
      providerAverageRating: (json['providerAverageRating'] as num?)?.toDouble(),
      providerTotalRatings: (json['providerTotalRatings'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'requestId': requestId,
        'customerId': customerId,
        'providerId': providerId,
        'score': score,
        'review': review,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };
}
