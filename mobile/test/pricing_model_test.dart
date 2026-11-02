import 'package:road_rescue/models/pricing_estimate_model.dart';

/// Permanent test suite for PricingEstimateModel.
///
/// Can be executed reliably on Windows using:
///   dart run test/pricing_model_test.dart
void main() {
  int passed = 0;
  int failed = 0;

  void testCase(String name, void Function() fn) {
    try {
      fn();
      print('  OK   $name');
      passed++;
    } catch (e, st) {
      print('  FAIL $name - $e');
      print(st);
      failed++;
    }
  }

  print('\n======================================================');
  print('🧪 ROADRESCUE FLUTTER PRICING MODEL TEST SUITE');
  print('======================================================\n');

  // ── 1. Valid Backend JSON Parsing ─────────────────────────────────────────
  testCase('1. Parse complete valid backend JSON payload', () {
    final json = {
      'pricingConfigId': 'cfg-uuid-1234',
      'matchedTier': 'EXACT_PROBLEM_AND_VEHICLE',
      'category': 'MECHANIC',
      'problemCategory': 'Engine Seized',
      'vehicleType': 'Heavy Vehicle',
      'currency': 'INR',
      'baseLaborCharge': 1500.0,
      'distanceKm': 15.5,
      'includedDistanceKm': 5.0,
      'billableDistanceKm': 10.5,
      'perKmCharge': 40.0,
      'distanceCharge': 420.0,
      'additionalCharges': 80.0,
      'subtotal': 2000.0,
      'taxRate': 0.18,
      'taxAmount': 360.0,
      'estimatedTotal': 2360.0,
      'isProvisional': true,
      'isDistanceEstimated': true,
      'distanceStatus': 'MEASURED_FROM_NEAREST_PROVIDER',
      'note': 'Provider travel charges will be calculated after provider assignment.',
      'calculatedAt': '2026-11-02T13:30:00.000Z',
    };

    final model = PricingEstimateModel.fromJson(json);

    assert(model.pricingConfigId == 'cfg-uuid-1234');
    assert(model.matchedTier == 'EXACT_PROBLEM_AND_VEHICLE');
    assert(model.category == 'MECHANIC');
    assert(model.problemCategory == 'Engine Seized');
    assert(model.vehicleType == 'Heavy Vehicle');
    assert(model.currency == 'INR');
    assert(model.matchedTierLabel == 'Specific Problem & Vehicle Rate');
  });

  // ── 2. Correct Estimated Total and Tax Parsing ────────────────────────────
  testCase('2. Parse correct total, tax, subtotal, and formatted currency', () {
    final json = {
      'pricingConfigId': 'cfg-5678',
      'matchedTier': 'CATEGORY_AND_VEHICLE',
      'category': 'PUNCTURE',
      'vehicleType': 'Car',
      'baseLaborCharge': 350.0,
      'distanceKm': 8.0,
      'includedDistanceKm': 3.0,
      'billableDistanceKm': 5.0,
      'perKmCharge': 15.0,
      'distanceCharge': 75.0,
      'additionalCharges': 25.0,
      'subtotal': 450.0,
      'taxRate': 0.18,
      'taxAmount': 81.0,
      'estimatedTotal': 531.0,
      'isProvisional': false,
      'isDistanceEstimated': false,
      'distanceStatus': 'MEASURED_TO_DESTINATION',
      'note': 'Confirmed route distance.',
    };

    final model = PricingEstimateModel.fromJson(json);

    assert(model.baseLaborCharge == 350.0);
    assert(model.distanceCharge == 75.0);
    assert(model.additionalCharges == 25.0);
    assert(model.subtotal == 450.0);
    assert(model.taxRate == 0.18);
    assert(model.taxAmount == 81.0);
    assert(model.estimatedTotal == 531.0);
    assert(model.formattedTotal == '₹531.00');
    assert(model.formattedSubtotal == '₹450.00');
    assert(model.formattedTax == '₹81.00');
    assert(model.formattedBaseLabor == '₹350.00');
    assert(model.formattedDistanceCharge == '₹75.00');
    assert(model.hasDistanceSurcharge == true);
    assert(model.hasAdditionalCharges == true);
  });

  // ── 3. Provisional Estimate Parsing ───────────────────────────────────────
  testCase('3. Parse provisional estimate flags and disclaimers', () {
    final json = {
      'pricingConfigId': 'cfg-base-only',
      'matchedTier': 'CATEGORY_DEFAULT',
      'category': 'BATTERY',
      'baseLaborCharge': 400.0,
      'distanceKm': 0.0,
      'includedDistanceKm': 5.0,
      'billableDistanceKm': 0.0,
      'perKmCharge': 20.0,
      'distanceCharge': 0.0,
      'additionalCharges': 0.0,
      'subtotal': 400.0,
      'taxRate': 0.18,
      'taxAmount': 72.0,
      'estimatedTotal': 472.0,
      'isProvisional': true,
      'isDistanceEstimated': false,
      'distanceStatus': 'NO_PROVIDER_AVAILABLE_BASE_ONLY',
      'note': 'Provider travel charges will be calculated after provider assignment.',
    };

    final model = PricingEstimateModel.fromJson(json);

    assert(model.isProvisional == true);
    assert(model.distanceStatus == 'NO_PROVIDER_AVAILABLE_BASE_ONLY');
    assert(model.distanceKm == 0.0);
    assert(model.distanceCharge == 0.0);
    assert(model.hasDistanceSurcharge == false);
    assert(model.note.contains('Provider travel charges will be calculated after provider assignment'));
    assert(model.matchedTierLabel == 'Standard Service Rate');
  });

  // ── 4. Missing Optional Fields ────────────────────────────────────────────
  testCase('4. Safely handle missing optional fields', () {
    // Minimal JSON containing only required identifiers
    final json = {
      'pricingConfigId': 'cfg-minimal',
      'category': 'TOW_TRUCK',
    };

    final model = PricingEstimateModel.fromJson(json);

    assert(model.pricingConfigId == 'cfg-minimal');
    assert(model.category == 'TOW_TRUCK');
    assert(model.problemCategory == null);
    assert(model.vehicleType == null);
    assert(model.currency == 'INR');
    assert(model.matchedTier == 'CATEGORY_DEFAULT');
    assert(model.baseLaborCharge == 0.0);
    assert(model.distanceKm == 0.0);
    assert(model.subtotal == 0.0);
    assert(model.taxRate == 0.18);
    assert(model.taxAmount == 0.0);
    assert(model.estimatedTotal == 0.0);
    assert(model.isProvisional == false);
    assert(model.distanceStatus == 'NO_PROVIDER_AVAILABLE_BASE_ONLY');
    assert(model.note == '');
    assert(model.calculatedAt == null);
  });

  // ── 5. Null Values in JSON ────────────────────────────────────────────────
  testCase('5. Safely handle explicit null values without crashing', () {
    final json = <String, dynamic>{
      'pricingConfigId': null,
      'matchedTier': null,
      'category': null,
      'problemCategory': null,
      'vehicleType': null,
      'currency': null,
      'baseLaborCharge': null,
      'distanceKm': null,
      'includedDistanceKm': null,
      'billableDistanceKm': null,
      'perKmCharge': null,
      'distanceCharge': null,
      'additionalCharges': null,
      'subtotal': null,
      'taxRate': null,
      'taxAmount': null,
      'estimatedTotal': null,
      'isProvisional': null,
      'isDistanceEstimated': null,
      'distanceStatus': null,
      'note': null,
      'calculatedAt': null,
    };

    final model = PricingEstimateModel.fromJson(json);

    assert(model.pricingConfigId == '');
    assert(model.matchedTier == 'CATEGORY_DEFAULT');
    assert(model.category == 'MECHANIC');
    assert(model.currency == 'INR');
    assert(model.baseLaborCharge == 0.0);
    assert(model.distanceKm == 0.0);
    assert(model.subtotal == 0.0);
    assert(model.taxAmount == 0.0);
    assert(model.estimatedTotal == 0.0);
    assert(model.isProvisional == false);
    assert(model.distanceStatus == 'NO_PROVIDER_AVAILABLE_BASE_ONLY');
    assert(model.note == '');
    assert(model.formattedTotal == '₹0.00');
  });

  // ── 6. Serialization Using toJson() ───────────────────────────────────────
  testCase('6. Serialize model back to JSON dictionary', () {
    const original = PricingEstimateModel(
      pricingConfigId: 'cfg-serialize-99',
      matchedTier: 'EXACT_PROBLEM_AND_VEHICLE',
      category: 'MECHANIC',
      problemCategory: 'Clutch Replacement',
      vehicleType: 'Car',
      currency: 'INR',
      baseLaborCharge: 1200.0,
      distanceKm: 10.0,
      includedDistanceKm: 5.0,
      billableDistanceKm: 5.0,
      perKmCharge: 20.0,
      distanceCharge: 100.0,
      additionalCharges: 50.0,
      subtotal: 1350.0,
      taxRate: 0.18,
      taxAmount: 243.0,
      estimatedTotal: 1593.0,
      isProvisional: false,
      isDistanceEstimated: false,
      distanceStatus: 'MEASURED_TO_DESTINATION',
      note: 'Exact route measured.',
      calculatedAt: '2026-11-02T14:00:00Z',
    );

    final serialized = original.toJson();

    assert(serialized['pricingConfigId'] == 'cfg-serialize-99');
    assert(serialized['matchedTier'] == 'EXACT_PROBLEM_AND_VEHICLE');
    assert(serialized['category'] == 'MECHANIC');
    assert(serialized['problemCategory'] == 'Clutch Replacement');
    assert(serialized['vehicleType'] == 'Car');
    assert(serialized['baseLaborCharge'] == 1200.0);
    assert(serialized['subtotal'] == 1350.0);
    assert(serialized['estimatedTotal'] == 1593.0);
    assert(serialized['isProvisional'] == false);

    // Re-parse serialized map
    final roundtrip = PricingEstimateModel.fromJson(serialized);
    assert(roundtrip.pricingConfigId == original.pricingConfigId);
    assert(roundtrip.estimatedTotal == original.estimatedTotal);
    assert(roundtrip.formattedTotal == original.formattedTotal);
  });

  print('\n======================================================');
  print('Pricing Model Tests Summary:');
  print('  Passed: $passed');
  print('  Failed: $failed');
  print('  Total:  ${passed + failed}');
  print('======================================================\n');

  if (failed > 0) {
    throw Exception('$failed pricing model test(s) failed.');
  }
}
