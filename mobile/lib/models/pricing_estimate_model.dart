class PricingEstimateModel {
  final String pricingConfigId;
  final String matchedTier;
  final String category;
  final String? problemCategory;
  final String? vehicleType;
  final String currency;
  final double baseLaborCharge;
  final double distanceKm;
  final double includedDistanceKm;
  final double billableDistanceKm;
  final double perKmCharge;
  final double distanceCharge;
  final double additionalCharges;
  final double subtotal;
  final double taxRate;
  final double taxAmount;
  final double estimatedTotal;
  final bool isProvisional;
  final bool isDistanceEstimated;
  final String distanceStatus;
  final String note;
  final String? calculatedAt;

  const PricingEstimateModel({
    required this.pricingConfigId,
    required this.matchedTier,
    required this.category,
    this.problemCategory,
    this.vehicleType,
    required this.currency,
    required this.baseLaborCharge,
    required this.distanceKm,
    required this.includedDistanceKm,
    required this.billableDistanceKm,
    required this.perKmCharge,
    required this.distanceCharge,
    required this.additionalCharges,
    required this.subtotal,
    required this.taxRate,
    required this.taxAmount,
    required this.estimatedTotal,
    required this.isProvisional,
    required this.isDistanceEstimated,
    required this.distanceStatus,
    required this.note,
    this.calculatedAt,
  });

  factory PricingEstimateModel.fromJson(Map<String, dynamic> json) {
    return PricingEstimateModel(
      pricingConfigId: json['pricingConfigId'] as String? ?? '',
      matchedTier: json['matchedTier'] as String? ?? 'CATEGORY_DEFAULT',
      category: json['category'] as String? ?? 'MECHANIC',
      problemCategory: json['problemCategory'] as String?,
      vehicleType: json['vehicleType'] as String?,
      currency: json['currency'] as String? ?? 'INR',
      baseLaborCharge: (json['baseLaborCharge'] as num?)?.toDouble() ?? 0.0,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      includedDistanceKm: (json['includedDistanceKm'] as num?)?.toDouble() ?? 0.0,
      billableDistanceKm: (json['billableDistanceKm'] as num?)?.toDouble() ?? 0.0,
      perKmCharge: (json['perKmCharge'] as num?)?.toDouble() ?? 0.0,
      distanceCharge: (json['distanceCharge'] as num?)?.toDouble() ?? 0.0,
      additionalCharges: (json['additionalCharges'] as num?)?.toDouble() ?? 0.0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      taxRate: (json['taxRate'] as num?)?.toDouble() ?? 0.18,
      taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0.0,
      estimatedTotal: (json['estimatedTotal'] as num?)?.toDouble() ?? 0.0,
      isProvisional: json['isProvisional'] as bool? ?? false,
      isDistanceEstimated: json['isDistanceEstimated'] as bool? ?? false,
      distanceStatus: json['distanceStatus'] as String? ?? 'NO_PROVIDER_AVAILABLE_BASE_ONLY',
      note: json['note'] as String? ?? '',
      calculatedAt: json['calculatedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pricingConfigId': pricingConfigId,
      'matchedTier': matchedTier,
      'category': category,
      if (problemCategory != null) 'problemCategory': problemCategory,
      if (vehicleType != null) 'vehicleType': vehicleType,
      'currency': currency,
      'baseLaborCharge': baseLaborCharge,
      'distanceKm': distanceKm,
      'includedDistanceKm': includedDistanceKm,
      'billableDistanceKm': billableDistanceKm,
      'perKmCharge': perKmCharge,
      'distanceCharge': distanceCharge,
      'additionalCharges': additionalCharges,
      'subtotal': subtotal,
      'taxRate': taxRate,
      'taxAmount': taxAmount,
      'estimatedTotal': estimatedTotal,
      'isProvisional': isProvisional,
      'isDistanceEstimated': isDistanceEstimated,
      'distanceStatus': distanceStatus,
      'note': note,
      if (calculatedAt != null) 'calculatedAt': calculatedAt,
    };
  }

  /// Formatted helpers for UI display
  String get formattedTotal => '₹${estimatedTotal.toStringAsFixed(2)}';
  String get formattedSubtotal => '₹${subtotal.toStringAsFixed(2)}';
  String get formattedTax => '₹${taxAmount.toStringAsFixed(2)}';
  String get formattedBaseLabor => '₹${baseLaborCharge.toStringAsFixed(2)}';
  String get formattedDistanceCharge => '₹${distanceCharge.toStringAsFixed(2)}';
  String get formattedAdditionalCharges => '₹${additionalCharges.toStringAsFixed(2)}';

  String get matchedTierLabel {
    switch (matchedTier) {
      case 'EXACT_PROBLEM_AND_VEHICLE':
        return 'Specific Problem & Vehicle Rate';
      case 'CATEGORY_AND_VEHICLE':
        return 'Vehicle-Specific Rate';
      case 'CATEGORY_DEFAULT':
      default:
        return 'Standard Service Rate';
    }
  }

  bool get hasDistanceSurcharge => distanceCharge > 0;
  bool get hasAdditionalCharges => additionalCharges > 0;
}
