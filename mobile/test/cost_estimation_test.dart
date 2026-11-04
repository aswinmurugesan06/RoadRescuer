import 'package:flutter_test/flutter_test.dart';
import 'package:road_rescue/services/cost_estimation_service.dart';

void main() {
  test('customer estimate applies callout, distance, labour and GST', () {
    final estimate = CostEstimationService.estimate(
      vehicleType: 'Car',
      issueCategory: 'Mechanic',
      distanceKm: 10,
      laborHours: 1,
    );

    expect(estimate.baseCallout, 199);
    expect(estimate.categoryBase, 0);
    expect(estimate.distanceCharge, 75);
    expect(estimate.laborCharge, 250);
    expect(estimate.partsEstimate, 0);
    expect(estimate.serviceSubtotal, closeTo(524, 0.01));
    expect(estimate.subtotal, closeTo(524, 0.01));
    expect(estimate.taxAmount, closeTo(94.32, 0.01));
    expect(estimate.total, closeTo(618.32, 0.01));
    expect(estimate.lowRange, closeTo(556.488, 0.01));
    expect(estimate.highRange, closeTo(680.152, 0.01));
  });

  test('vehicle multiplier applies to service portion but not parts', () {
    final car = CostEstimationService.estimate(
      vehicleType: 'Car',
      issueCategory: 'Puncture',
      distanceKm: 8,
      laborHours: 0.5,
      partsEstimate: 1000,
    );
    final heavy = CostEstimationService.estimate(
      vehicleType: 'Heavy Vehicle',
      issueCategory: 'Puncture',
      distanceKm: 8,
      laborHours: 0.5,
      partsEstimate: 1000,
    );

    expect(car.serviceSubtotal, closeTo(369, 0.01));
    expect(car.subtotal, closeTo(1369, 0.01));
    expect(heavy.serviceSubtotal, closeTo(590.4, 0.01));
    expect(heavy.subtotal, closeTo(1590.4, 0.01));
    expect(heavy.total, greaterThan(car.total));
    expect(heavy.vehicleMultiplier, 1.6);
  });

  test('customer auto labour follows category baselines and severity', () {
    expect(CostEstimationService.autoLaborHours('Puncture'), 0.5);
    expect(CostEstimationService.autoLaborHours('Battery'), 0.5);
    expect(CostEstimationService.autoLaborHours('Fuel'), 0.5);
    expect(CostEstimationService.autoLaborHours('Tow'), 1.0);
    expect(CostEstimationService.autoLaborHours('Mechanic'), 1.5);
    expect(
      CostEstimationService.autoLaborHours('Mechanic', severity: 'Severe'),
      1.88,
    );
    expect(
      CostEstimationService.autoLaborHours('Mechanic', severity: 'Low'),
      1.2,
    );
  });

  test('customer estimate auto-fills baseline labour and zero parts', () {
    final estimate = CostEstimationService.estimateForCustomer(
      vehicleType: 'Bike',
      issueCategory: 'Mechanic',
    );

    expect(estimate.distanceKm, CostEstimationService.defaultDistanceKm);
    expect(estimate.laborHours, 1.5);
    expect(estimate.laborCharge, 375);
    expect(estimate.partsEstimate, 0);
    expect(estimate.vehicleMultiplier, 0.85);
  });
}
