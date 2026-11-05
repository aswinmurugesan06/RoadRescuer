import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:road_rescue/services/ai_damage_service.dart';
import 'package:road_rescue/services/cost_estimation_service.dart';

AiDamageResult _geminiResult() {
  final body = jsonEncode({
    'candidates': [
      {
        'content': {
          'parts': [
            {
              'text': '''
```json
{
  "damageTitle": "Front left tyre is flat",
  "detectedType": "Flat tire",
  "mappedCategory": "Puncture",
  "severity": "Severe",
  "visibleIndicators": [
    "Tyre is visibly deflated",
    "Nail embedded in the tread"
  ],
  "requiredTools": ["Hydraulic jack", "Wheel spanner", "Tyre levers"],
  "recommendedParts": ["Replacement tyre", "Valve stem"],
  "estimatedLaborHours": 1.5,
  "estimatedPartsCost": 1800,
  "mechanicPrepNote": "Bring a matching 17-inch tyre and a portable inflator."
}
```
''',
            },
          ],
        },
      },
    ],
  });
  return AiDamageService.parseGeminiBody(body);
}

void main() {
  test('offline mock assessment is deterministic and complete', () {
    final first = AiDamageService.mockResult(vehicleType: 'Car', seed: 11);
    final second = AiDamageService.mockResult(vehicleType: 'Car', seed: 11);

    expect(first.isFallback, isTrue);
    expect(first.damageTitle, isNotEmpty);
    expect(
      CostEstimationService.issueCategories,
      contains(first.mappedCategory),
    );
    expect(first.visibleIndicators, isNotEmpty);
    expect(first.requiredTools, isNotEmpty);
    expect(first.recommendedParts, isNotEmpty);
    expect(first.estimatedLaborHours, inInclusiveRange(0.25, 8));
    expect(first.estimatedPartsCost, greaterThan(0));

    expect(second.damageTitle, first.damageTitle);
    expect(second.mappedCategory, first.mappedCategory);
    expect(second.estimatedPartsCost, first.estimatedPartsCost);
  });

  test('assess returns unavailable instead of inventing damage without keys',
      () async {
    if (AiDamageService.hasGemini || AiDamageService.hasCloudinary) {
      // A developer is running with live dart-defines; the offline path is
      // covered by the deterministic mock test above.
      return;
    }

    final bytes = Uint8List.fromList(List.generate(64, (index) => index * 5));
    final assessment = await AiDamageService.assess(
      imageBytes: bytes,
      vehicleType: 'Bike',
      fallbackCategory: 'Battery',
    );

    expect(assessment.imageUrl, startsWith('data:image/'));
    expect(assessment.result.isAnalysisUnavailable, isTrue);
    expect(assessment.result.isVehicleImage, isFalse);
    expect(assessment.result.requiredTools, isEmpty);
    expect(assessment.result.recommendedParts, isEmpty);
    expect(assessment.result.estimatedLaborHours, 0);
    expect(assessment.result.estimatedPartsCost, 0);
  });

  test('unavailable result never maps to Firestore AI fields', () {
    final result = AiDamageResult.unavailable(
      reason: 'AI analysis timed out.',
    );
    expect(result.isAnalysisUnavailable, isTrue);
    expect(result.isVehicleImage, isFalse);
    expect(result.toRequestFields(), isEmpty);
  });

  test('Gemini body parsing handles fenced JSON and exact fields', () {
    final result = _geminiResult();

    expect(result.damageTitle, 'Front left tyre is flat');
    expect(result.detectedType, 'Flat tire');
    expect(result.mappedCategory, 'Puncture');
    expect(result.severity, 'Severe');
    expect(result.visibleIndicators, hasLength(2));
    expect(result.requiredTools, contains('Hydraulic jack'));
    expect(result.recommendedParts, contains('Replacement tyre'));
    expect(result.estimatedLaborHours, 1.5);
    expect(result.estimatedPartsCost, 1800);
    expect(result.mechanicPrepNote, contains('17-inch'));
    expect(result.isFallback, isFalse);
  });

  test('unsafe Gemini values are normalised with safe defaults', () {
    final result = AiDamageResult.fromJson({
      'damageTitle': '   ',
      'detectedType': '',
      'mappedCategory': 'tyre / flat',
      'severity': 'high risk',
      'visibleIndicators': 'not-a-list',
      'requiredTools': <String>[],
      'recommendedParts': <String>[],
      'estimatedLaborHours': 99,
      'estimatedPartsCost': -50,
      'mechanicPrepNote': '',
    });

    expect(result.detectedType, 'Flat tire');
    expect(result.mappedCategory, 'Puncture');
    expect(result.severity, 'Severe');
    expect(result.visibleIndicators, isNotEmpty);
    expect(result.requiredTools, isNotEmpty);
    expect(result.recommendedParts, isNotEmpty);
    expect(result.estimatedLaborHours, 8);
    expect(result.estimatedPartsCost, 0);
    expect(result.mechanicPrepNote, isNotEmpty);
  });

  test('Cloudinary secure_url extraction is defensive', () {
    expect(
      AiDamageService.extractSecureUrl(
        '{"secure_url":"https://res.cloudinary.com/demo/image/upload/a.jpg"}',
      ),
      'https://res.cloudinary.com/demo/image/upload/a.jpg',
    );
    expect(AiDamageService.extractSecureUrl('{"public_id":"x"}'), isEmpty);
    expect(AiDamageService.extractSecureUrl('not-json'), isEmpty);
  });

  test('non-vehicle image is rejected with a clear warning', () {
    final result = AiDamageResult.fromJson({
      'isVehicleImage': false,
      'invalidReason': 'A person is visible, not a vehicle or vehicle part.',
    });

    expect(result.isVehicleImage, isFalse);
    expect(result.damageTitle, 'Not a valid vehicle image');
    expect(result.detectedType, 'Not a vehicle');
    expect(result.visibleIndicators, isEmpty);
    expect(result.requiredTools, isEmpty);
    expect(result.recommendedParts, isEmpty);
    expect(result.estimatedLaborHours, 0);
    expect(result.estimatedPartsCost, 0);
    expect(result.invalidReason, contains('person'));
    expect(result.toRequestFields(), isEmpty);
  });

  test('Gemini response can reject a non-vehicle image', () {
    final body = jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {
                'text': '''
{
  "isVehicleImage": false,
  "invalidReason": "The image shows a plate of food, not a vehicle.",
  "damageTitle": "",
  "detectedType": "",
  "mappedCategory": "Mechanic",
  "severity": "Low",
  "visibleIndicators": [],
  "requiredTools": [],
  "recommendedParts": [],
  "estimatedLaborHours": 0,
  "estimatedPartsCost": 0,
  "mechanicPrepNote": ""
}
''',
              },
            ],
          },
        },
      ],
    });

    final result = AiDamageService.parseGeminiBody(body);
    expect(result.isVehicleImage, isFalse);
    expect(result.invalidReason, contains('food'));
    expect(result.requiredTools, isEmpty);
  });

  test('string boolean false is treated as invalid', () {
    final result = AiDamageResult.fromJson({
      'isVehicleImage': 'false',
      'invalidReason': 'No vehicle is visible.',
    });
    expect(result.isVehicleImage, isFalse);
  });

  test('AI result feeds the existing cost formula exactly', () {
    final result = AiDamageResult.fromJson({
      'damageTitle': 'Battery terminal corrosion',
      'detectedType': 'Battery issue',
      'mappedCategory': 'Battery',
      'severity': 'Moderate',
      'visibleIndicators': ['White corrosion on terminal'],
      'requiredTools': ['Battery brush', 'Multimeter'],
      'recommendedParts': ['Battery terminal clamp'],
      'estimatedLaborHours': 0.5,
      'estimatedPartsCost': 850,
      'mechanicPrepNote': 'Clean the terminals and test the alternator.',
    });

    final estimate = CostEstimationService.estimate(
      vehicleType: 'Car',
      issueCategory: result.mappedCategory,
      distanceKm: 10,
      laborHours: result.estimatedLaborHours,
      partsEstimate: result.estimatedPartsCost,
    );

    expect(estimate.baseCallout, 199);
    expect(estimate.categoryBase, 0);
    expect(estimate.distanceCharge, 75);
    expect(estimate.laborCharge, 125);
    expect(estimate.serviceSubtotal, closeTo(399, 0.01));
    expect(estimate.subtotal, closeTo(1249, 0.01));
    expect(estimate.taxAmount, closeTo(224.82, 0.01));
    expect(estimate.total, closeTo(1473.82, 0.01));
    expect(estimate.lowRange, closeTo(1326.438, 0.01));
    expect(estimate.highRange, closeTo(1621.202, 0.01));
  });

  test('assessment maps to Firestore request fields', () {
    final assessment = AiDamageAssessment(
      result: _geminiResult(),
      imageUrl: 'https://res.cloudinary.com/demo/image/upload/damage.jpg',
    );
    final fields = assessment.toRequestFields(estimatedAmount: 2100);

    expect(fields['damageImageUrl'], startsWith('https://res.cloudinary.com'));
    expect(fields['aiDetectedIssue'], 'Front left tyre is flat');
    expect(fields['aiSeverity'], 'Severe');
    expect(fields['visibleIndicators'], isA<List<String>>());
    expect(fields['requiredTools'], isA<List<String>>());
    expect(fields['recommendedParts'], isA<List<String>>());
    expect(fields['estimatedLaborHours'], 1.5);
    expect(fields['estimatedPartsCost'], 1800);
    expect(fields['mechanicPrepNote'], isNotEmpty);
    expect(fields['estimatedAmount'], 2100);
  });
}
