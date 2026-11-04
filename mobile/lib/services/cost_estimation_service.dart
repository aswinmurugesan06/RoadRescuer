/// Dynamic roadside repair cost estimation.
///
/// Customer flow (read-only):
///   callout + auto distance + auto labour + AI/manual parts, vehicle multiplier
///   applied to the service portion only, then 18% GST.
///
/// Provider flow:
///   the same formula with manually adjustable labour hours and parts.
class CostEstimate {
  final String vehicleType;
  final String issueCategory;
  final double distanceKm;
  final double laborHours;
  final double partsEstimate;
  final double vehicleMultiplier;
  final double baseCallout;

  /// Retained for API compatibility; category pricing now comes from
  /// [CostEstimationService.baselineLaborHours].
  final double categoryBase;
  final double distanceCharge;
  final double laborCharge;
  final double serviceSubtotal;
  final double subtotal;
  final double taxAmount;
  final double total;
  final double lowRange;
  final double highRange;

  const CostEstimate({
    required this.vehicleType,
    required this.issueCategory,
    required this.distanceKm,
    required this.laborHours,
    required this.partsEstimate,
    required this.vehicleMultiplier,
    required this.baseCallout,
    required this.categoryBase,
    required this.distanceCharge,
    required this.laborCharge,
    required this.serviceSubtotal,
    required this.subtotal,
    required this.taxAmount,
    required this.total,
    required this.lowRange,
    required this.highRange,
  });
}

class CostEstimationService {
  CostEstimationService._();

  static const double baseCallout = 199;
  static const double freeDistanceKm = 5;
  static const double distanceRatePerKm = 15;
  static const double laborRatePerHour = 250;
  static const double taxRate = 0.18;
  static const double defaultDistanceKm = 10;

  static const Map<String, double> vehicleMultipliers = {
    'Bike': 0.85,
    'Auto': 0.95,
    'Car': 1.0,
    'Van': 1.10,
    'Light Commercial Vehicle': 1.25,
    'Bus': 1.40,
    'Heavy Vehicle': 1.60,
  };

  /// Standard labour hours used when no AI assessment is available.
  static const Map<String, double> baselineLaborHours = {
    'Puncture': 0.5,
    'Battery': 0.5,
    'Fuel': 0.5,
    'Tow': 1.0,
    'Mechanic': 1.5,
  };

  static const List<String> issueCategories = [
    'Mechanic',
    'Puncture',
    'Tow',
    'Battery',
    'Fuel',
  ];

  /// Auto labour hours for a category, scaled by AI/urgency severity.
  static double autoLaborHours(
    String issueCategory, {
    String? severity,
  }) {
    final base = baselineLaborHours[issueCategory] ?? 1.5;
    final multiplier = severityMultiplier(severity);
    return double.parse((base * multiplier).toStringAsFixed(2));
  }

  static double severityMultiplier(String? severity) {
    switch ((severity ?? '').trim().toLowerCase()) {
      case 'severe':
      case 'high':
      case 'critical':
        return 1.25;
      case 'low':
      case 'minor':
        return 0.8;
      default:
        return 1.0;
    }
  }

  /// Customer estimate: labour and distance are automatic and read-only.
  static CostEstimate estimateForCustomer({
    required String vehicleType,
    required String issueCategory,
    double distanceKm = defaultDistanceKm,
    double partsEstimate = 0,
    String? severity,
  }) {
    return estimate(
      vehicleType: vehicleType,
      issueCategory: issueCategory,
      distanceKm: distanceKm,
      laborHours: autoLaborHours(issueCategory, severity: severity),
      partsEstimate: partsEstimate,
    );
  }

  static CostEstimate estimate({
    required String vehicleType,
    required String issueCategory,
    required double distanceKm,
    required double laborHours,
    double partsEstimate = 0,
    double laborRate = laborRatePerHour,
    double distanceRate = distanceRatePerKm,
  }) {
    final multiplier = vehicleMultipliers[vehicleType] ?? 1.0;
    final chargeableDistance =
        distanceKm > freeDistanceKm ? distanceKm - freeDistanceKm : 0.0;
    final distanceCharge = chargeableDistance * distanceRate;
    final laborCharge = laborHours * laborRate;

    // Vehicle multiplier applies to the service portion only. Parts are added
    // at cost, which matches how a real garage bills a customer.
    final serviceSubtotal =
        (baseCallout + distanceCharge + laborCharge) * multiplier;
    final subtotal = serviceSubtotal + partsEstimate;
    final taxAmount = subtotal * taxRate;
    final total = subtotal + taxAmount;

    return CostEstimate(
      vehicleType: vehicleType,
      issueCategory: issueCategory,
      distanceKm: distanceKm,
      laborHours: laborHours,
      partsEstimate: partsEstimate,
      vehicleMultiplier: multiplier,
      baseCallout: baseCallout,
      categoryBase: 0,
      distanceCharge: distanceCharge,
      laborCharge: laborCharge,
      serviceSubtotal: serviceSubtotal,
      subtotal: subtotal,
      taxAmount: taxAmount,
      total: total,
      lowRange: total * 0.9,
      highRange: total * 1.1,
    );
  }
}
