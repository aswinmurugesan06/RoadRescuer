import 'package:flutter_test/flutter_test.dart';
import 'package:road_rescue/services/cost_estimation_service.dart';

void main() {
  test('dynamic cost estimate includes distance, labor and GST', () {
    final estimate = CostEstimationService.estimate(
      vehicleType: 'Car',
      issueCategory: 'Mechanic',
      distanceKm: 10,
      laborHours: 1,
    );

    expect(estimate.baseCallout, 199);
    expect(estimate.categoryBase, 450);
    expect(estimate.distanceCharge, 75);
    expect(estimate.laborCharge, 250);
    expect(estimate.subtotal, closeTo(974, 0.01));
    expect(estimate.taxAmount, closeTo(175.32, 0.01));
    expect(estimate.total, closeTo(1149.32, 0.01));
    expect(estimate.lowRange, closeTo(1034.388, 0.01));
    expect(estimate.highRange, closeTo(1264.252, 0.01));
  });

  test('vehicle type multiplier changes the total', () {
    final car = CostEstimationService.estimate(
      vehicleType: 'Car',
      issueCategory: 'Puncture',
      distanceKm: 8,
      laborHours: 0.5,
    );
    final heavy = CostEstimationService.estimate(
      vehicleType: 'Heavy Vehicle',
      issueCategory: 'Puncture',
      distanceKm: 8,
      laborHours: 0.5,
    );

    expect(heavy.total, greaterThan(car.total));
    expect(heavy.vehicleMultiplier, 1.6);
  });
}
