/// Dynamic roadside repair cost estimation.
///
/// The estimate combines a fixed callout, the issue category, distance beyond
/// the free radius, labor hours, optional parts, a vehicle-type multiplier and
/// GST. It is intentionally transparent so the app can show a breakdown before
/// the customer books.
class CostEstimate {
  final String vehicleType;
  final String issueCategory;
  final double distanceKm;
  final double laborHours;
  final double partsEstimate;
  final double vehicleMultiplier;
  final double baseCallout;
  final double categoryBase;
  final double distanceCharge;
  final double laborCharge;
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

  static const Map<String, double> vehicleMultipliers = {
    'Bike': 0.85,
    'Auto': 0.95,
    'Car': 1.0,
    'Van': 1.10,
    'Light Commercial Vehicle': 1.25,
    'Bus': 1.40,
    'Heavy Vehicle': 1.60,
  };

  static const Map<String, double> categoryBases = {
    'Mechanic': 450,
    'Puncture': 300,
    'Tow': 800,
    'Battery': 350,
    'Fuel': 250,
  };

  static const List<String> issueCategories = [
    'Mechanic',
    'Puncture',
    'Tow',
    'Battery',
    'Fuel',
  ];

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
    final categoryBase = categoryBases[issueCategory] ?? 450;
    final chargeableDistance =
        distanceKm > freeDistanceKm ? distanceKm - freeDistanceKm : 0.0;
    final distanceCharge = chargeableDistance * distanceRate;
    final laborCharge = laborHours * laborRate;

    final subtotal = (baseCallout +
            categoryBase +
            distanceCharge +
            laborCharge +
            partsEstimate) *
        multiplier;
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
      categoryBase: categoryBase,
      distanceCharge: distanceCharge,
      laborCharge: laborCharge,
      subtotal: subtotal,
      taxAmount: taxAmount,
      total: total,
      lowRange: total * 0.9,
      highRange: total * 1.1,
    );
  }
}
