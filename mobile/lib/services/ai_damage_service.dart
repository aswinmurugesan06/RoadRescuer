import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// One AI vision assessment for a vehicle photo.
///
/// The fields map 1:1 to the Firestore fields stored on `serviceRequests`.
class AiDamageResult {
  final String damageTitle;
  final String detectedType;
  final String mappedCategory;
  final String severity;
  final List<String> visibleIndicators;
  final List<String> requiredTools;
  final List<String> recommendedParts;
  final double estimatedLaborHours;
  final double estimatedPartsCost;
  final String mechanicPrepNote;

  /// True when the result came from the deterministic offline fallback.
  final bool isFallback;

  const AiDamageResult({
    required this.damageTitle,
    required this.detectedType,
    required this.mappedCategory,
    required this.severity,
    required this.visibleIndicators,
    required this.requiredTools,
    required this.recommendedParts,
    required this.estimatedLaborHours,
    required this.estimatedPartsCost,
    required this.mechanicPrepNote,
    this.isFallback = false,
  });

  factory AiDamageResult.fromJson(
    Map<String, dynamic> json, {
    bool isFallback = false,
  }) {
    final mappedCategory = AiDamageService._normalizeCategory(
      json['mappedCategory']?.toString(),
    );
    final detectedType = AiDamageService._normalizeDetectedType(
      json['detectedType']?.toString(),
      mappedCategory,
    );
    final severity = AiDamageService._normalizeSeverity(
      json['severity']?.toString(),
    );

    final indicators = AiDamageService._cleanList(json['visibleIndicators']);
    final tools = AiDamageService._cleanList(json['requiredTools']);
    final parts = AiDamageService._cleanList(json['recommendedParts']);

    return AiDamageResult(
      damageTitle: AiDamageService._cleanText(
        json['damageTitle'],
        fallback: AiDamageService._defaultTitle(detectedType),
      ),
      detectedType: detectedType,
      mappedCategory: mappedCategory,
      severity: severity,
      visibleIndicators: indicators.isEmpty
          ? AiDamageService._defaultIndicators(detectedType)
          : indicators,
      requiredTools: tools.isEmpty
          ? AiDamageService._defaultTools(detectedType)
          : tools,
      recommendedParts: parts.isEmpty
          ? AiDamageService._defaultParts(detectedType)
          : parts,
      estimatedLaborHours: AiDamageService._cleanDouble(
        json['estimatedLaborHours'],
        fallback: AiDamageService._defaultLaborHours(detectedType),
        min: 0.25,
        max: 8,
      ),
      estimatedPartsCost: AiDamageService._cleanDouble(
        json['estimatedPartsCost'],
        fallback: AiDamageService._defaultPartsCost(detectedType),
        min: 0,
        max: 200000,
      ),
      mechanicPrepNote: AiDamageService._cleanText(
        json['mechanicPrepNote'],
        fallback: AiDamageService._defaultPrepNote(detectedType),
      ),
      isFallback: isFallback,
    );
  }

  AiDamageResult copyWith({
    String? damageTitle,
    String? detectedType,
    String? mappedCategory,
    String? severity,
    List<String>? visibleIndicators,
    List<String>? requiredTools,
    List<String>? recommendedParts,
    double? estimatedLaborHours,
    double? estimatedPartsCost,
    String? mechanicPrepNote,
    bool? isFallback,
  }) {
    return AiDamageResult(
      damageTitle: damageTitle ?? this.damageTitle,
      detectedType: detectedType ?? this.detectedType,
      mappedCategory: mappedCategory ?? this.mappedCategory,
      severity: severity ?? this.severity,
      visibleIndicators: visibleIndicators ?? this.visibleIndicators,
      requiredTools: requiredTools ?? this.requiredTools,
      recommendedParts: recommendedParts ?? this.recommendedParts,
      estimatedLaborHours: estimatedLaborHours ?? this.estimatedLaborHours,
      estimatedPartsCost: estimatedPartsCost ?? this.estimatedPartsCost,
      mechanicPrepNote: mechanicPrepNote ?? this.mechanicPrepNote,
      isFallback: isFallback ?? this.isFallback,
    );
  }

  /// Firestore payload for the `serviceRequests` document.
  Map<String, dynamic> toRequestFields() {
    return {
      'aiDetectedIssue': damageTitle,
      'aiSeverity': severity,
      'visibleIndicators': visibleIndicators,
      'requiredTools': requiredTools,
      'recommendedParts': recommendedParts,
      'estimatedLaborHours': estimatedLaborHours,
      'estimatedPartsCost': estimatedPartsCost,
      'mechanicPrepNote': mechanicPrepNote,
    };
  }
}

/// A combined Cloudinary image URL + Gemini vision result.
class AiDamageAssessment {
  final AiDamageResult result;
  final String imageUrl;

  const AiDamageAssessment({
    required this.result,
    this.imageUrl = '',
  });

  AiDamageAssessment copyWith({
    AiDamageResult? result,
    String? imageUrl,
  }) {
    return AiDamageAssessment(
      result: result ?? this.result,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  Map<String, dynamic> toRequestFields({double? estimatedAmount}) {
    return {
      ...result.toRequestFields(),
      if (imageUrl.trim().isNotEmpty) 'damageImageUrl': imageUrl.trim(),
      if (estimatedAmount != null) 'estimatedAmount': estimatedAmount,
    };
  }
}

/// Direct REST integration for Gemini Vision and Cloudinary.
///
/// No heavy SDKs are used. When credentials are missing (unit tests, offline
/// demos) or a remote call fails, a deterministic smart mock is returned so the
/// app never crashes.
class AiDamageService {
  AiDamageService._();

  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );
  static const String geminiModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-2.5-flash',
  );
  static const String cloudinaryCloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: '',
  );
  static const String cloudinaryUploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: '',
  );

  static bool get hasGemini => geminiApiKey.trim().isNotEmpty;

  static bool get hasCloudinary =>
      cloudinaryCloudName.trim().isNotEmpty &&
      cloudinaryUploadPreset.trim().isNotEmpty;

  /// Uploads the photo and analyses it at the same time.
  static Future<AiDamageAssessment> assess({
    required Uint8List imageBytes,
    required String vehicleType,
  }) async {
    if (imageBytes.isEmpty) {
      return AiDamageAssessment(
        result: mockResult(vehicleType: vehicleType),
      );
    }

    // Each helper is failure-safe, so Future.wait cannot reject the whole UI.
    final results = await Future.wait<Object>([
      uploadDamageImage(imageBytes),
      analyzeVehicleDamage(imageBytes: imageBytes, vehicleType: vehicleType),
    ]);

    return AiDamageAssessment(
      result: results[1] as AiDamageResult,
      imageUrl: results[0] as String,
    );
  }

  /// Cloudinary unsigned upload. Returns `''` when unavailable.
  static Future<String> uploadDamageImage(
    Uint8List imageBytes, {
    String fileName = 'damage.jpg',
  }) async {
    if (!hasCloudinary || imageBytes.isEmpty) return '';

    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/${cloudinaryCloudName.trim()}/image/upload',
      );
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = cloudinaryUploadPreset.trim()
        ..fields['folder'] = 'road_rescue_damage'
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            imageBytes,
            filename: fileName,
          ),
        );

      final streamed = await request.send().timeout(const Duration(seconds: 25));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode < 200 || response.statusCode >= 300) return '';
      return extractSecureUrl(response.body);
    } catch (_) {
      return '';
    }
  }

  /// Gemini Vision REST call. Falls back to [mockResult] on any failure.
  static Future<AiDamageResult> analyzeVehicleDamage({
    required Uint8List imageBytes,
    required String vehicleType,
  }) async {
    if (!hasGemini || imageBytes.isEmpty) {
      return mockResult(
        vehicleType: vehicleType,
        seed: _seedFor(imageBytes),
      );
    }

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': _buildPrompt(vehicleType)},
            {
              'inline_data': {
                'mime_type': _mimeTypeFor(imageBytes),
                'data': base64Encode(imageBytes),
              },
            },
          ],
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'temperature': 0.2,
      },
    });

    for (final model in _modelsToTry) {
      try {
        final uri = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/'
          '$model:generateContent?key=${geminiApiKey.trim()}',
        );
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: body,
            )
            .timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          return parseGeminiBody(response.body);
        }

        // 404 means this model is retired for the key. 503/429 is transient.
        if (response.statusCode == 404 ||
            response.statusCode == 503 ||
            response.statusCode == 429) {
          continue;
        }
        return mockResult(
          vehicleType: vehicleType,
          seed: _seedFor(imageBytes),
        );
      } catch (_) {
        // Try the next model, then fall back to the local assessment.
      }
    }

    return mockResult(
      vehicleType: vehicleType,
      seed: _seedFor(imageBytes),
    );
  }

  /// Parses a Gemini `generateContent` response body.
  ///
  /// Public so it can be unit-tested without network access.
  static AiDamageResult parseGeminiBody(String body) {
    final decoded = jsonDecode(body);

    if (decoded is Map) {
      // Some callers may pass the raw assessment object directly.
      if (decoded.containsKey('damageTitle')) {
        return AiDamageResult.fromJson(Map<String, dynamic>.from(decoded));
      }

      final candidates = decoded['candidates'];
      if (candidates is List && candidates.isNotEmpty) {
        final first = candidates.first;
        if (first is Map) {
          final content = first['content'];
          if (content is Map) {
            final parts = content['parts'];
            if (parts is List) {
              final text = parts
                  .whereType<Map>()
                  .map((part) => part['text'])
                  .whereType<String>()
                  .join('\n')
                  .trim();
              if (text.isNotEmpty) {
                final jsonText = _extractJsonObject(text);
                final parsed = jsonDecode(jsonText);
                if (parsed is Map) {
                  return AiDamageResult.fromJson(
                    Map<String, dynamic>.from(parsed),
                  );
                }
              }
            }
          }
        }
      }
    }

    throw const FormatException('Gemini returned no usable JSON.');
  }

  /// Extracts `secure_url` from a Cloudinary upload response.
  static String extractSecureUrl(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['secure_url'] is String) {
        return decoded['secure_url'] as String;
      }
    } catch (_) {
      // Fall through to empty.
    }
    return '';
  }

  /// Deterministic offline assessment used by tests and offline demos.
  static AiDamageResult mockResult({
    required String vehicleType,
    int seed = 0,
  }) {
    const types = ['Flat tire', 'Broken light', 'Body damage', 'Battery issue'];
    final type = types[seed.abs() % types.length];
    final mapped = _categoryFor(type);
    final severity = _severityForSeed(seed);
    final tools = _defaultTools(type);
    final parts = _defaultParts(type);

    return AiDamageResult(
      damageTitle: _defaultTitle(type),
      detectedType: type,
      mappedCategory: mapped,
      severity: severity,
      visibleIndicators: _defaultIndicators(type),
      requiredTools: tools,
      recommendedParts: parts,
      estimatedLaborHours: _defaultLaborHours(type),
      estimatedPartsCost: _defaultPartsCost(type),
      mechanicPrepNote:
          '${_defaultPrepNote(type)} Prepare ${tools.length} tools and '
          '${parts.length} spare parts before departing for the $vehicleType.',
      isFallback: true,
    );
  }

  // ── Internals ─────────────────────────────────────────────────────────

  static List<String> get _modelsToTry {
    final configured = geminiModel.trim().isEmpty
        ? 'gemini-2.5-flash'
        : geminiModel.trim();
    return <String>{
      configured,
      'gemini-3.5-flash',
      'gemini-3.8-flash',
    }.toList(growable: false);
  }

  static String _buildPrompt(String vehicleType) {
    return '''
You are RoadRescue's vehicle damage vision assistant.
Analyze the uploaded image of a $vehicleType for visible roadside damage.
Classify the visible damage into exactly one of these four target areas:
- Flat tire
- Broken light
- Body damage
- Battery issue (visible indicators such as corrosion, loose terminal, swollen case, or battery warning light)

Return ONLY one valid JSON object (no markdown, no explanation) with this exact structure:
{
  "damageTitle": "Short clear title of the visible issue",
  "detectedType": "Flat tire | Broken light | Body damage | Battery issue",
  "mappedCategory": "Puncture | Mechanic | Tow | Battery | Fuel",
  "severity": "Low | Moderate | Severe",
  "visibleIndicators": ["Indicator 1", "Indicator 2"],
  "requiredTools": ["Tool 1", "Tool 2", "Tool 3"],
  "recommendedParts": ["Part 1", "Part 2"],
  "estimatedLaborHours": 1.0,
  "estimatedPartsCost": 250,
  "mechanicPrepNote": "Concise preparation instruction for the mechanic"
}
Use Indian rupee amounts for estimatedPartsCost. Be conservative with severity and only report what is visible.
''';
  }

  static String _mimeTypeFor(Uint8List bytes) {
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return 'image/jpeg';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  static int _seedFor(Uint8List bytes) {
    if (bytes.isEmpty) return 0;
    var seed = bytes.length;
    final step = math.max(1, bytes.length ~/ 64).toInt();
    for (var i = 0; i < bytes.length; i += step) {
      seed = (seed * 31 + bytes[i]) & 0x7fffffff;
    }
    return seed;
  }

  static String _extractJsonObject(String text) {
    var cleaned = text.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
      cleaned = cleaned.replaceFirst(RegExp(r'\s*```$'), '');
    }
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      throw const FormatException('No JSON object found.');
    }
    return cleaned.substring(start, end + 1);
  }

  static String _cleanText(dynamic value, {required String fallback}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static List<String> _cleanList(dynamic value, {int max = 8}) {
    if (value is! List) return const [];
    final cleaned = <String>[];
    for (final item in value) {
      final text = item?.toString().trim() ?? '';
      if (text.isNotEmpty && !cleaned.contains(text)) cleaned.add(text);
      if (cleaned.length >= max) break;
    }
    return cleaned;
  }

  static double _cleanDouble(
    dynamic value, {
    required double fallback,
    required double min,
    required double max,
  }) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    if (parsed == null || parsed.isNaN || parsed.isInfinite) return fallback;
    return parsed.clamp(min, max).toDouble();
  }

  static String _normalizeCategory(String? raw) {
    final value = (raw ?? '').toLowerCase();
    if (value.contains('puncture') ||
        value.contains('tyre') ||
        value.contains('tire') ||
        value.contains('flat')) {
      return 'Puncture';
    }
    if (value.contains('tow') || value.contains('recovery')) return 'Tow';
    if (value.contains('battery') || value.contains('electrical')) {
      return 'Battery';
    }
    if (value.contains('fuel') || value.contains('diesel')) return 'Fuel';
    return 'Mechanic';
  }

  static String _normalizeDetectedType(String? raw, String mappedCategory) {
    final value = (raw ?? '').toLowerCase();
    if (value.contains('flat') ||
        value.contains('tyre') ||
        value.contains('tire')) {
      return 'Flat tire';
    }
    if (value.contains('light') || value.contains('lamp')) {
      return 'Broken light';
    }
    if (value.contains('battery')) return 'Battery issue';
    if (value.contains('body') ||
        value.contains('dent') ||
        value.contains('panel') ||
        value.contains('scratch')) {
      return 'Body damage';
    }
    switch (mappedCategory) {
      case 'Puncture':
        return 'Flat tire';
      case 'Battery':
        return 'Battery issue';
      case 'Tow':
        return 'Body damage';
      default:
        return 'Body damage';
    }
  }

  static String _normalizeSeverity(String? raw) {
    final value = (raw ?? '').toLowerCase();
    if (value.contains('severe') || value.contains('high')) return 'Severe';
    if (value.contains('low') || value.contains('minor')) return 'Low';
    return 'Moderate';
  }

  static String _severityForSeed(int seed) {
    switch (seed.abs() % 3) {
      case 0:
        return 'Low';
      case 1:
        return 'Moderate';
      default:
        return 'Severe';
    }
  }

  static String _categoryFor(String type) {
    switch (type) {
      case 'Flat tire':
        return 'Puncture';
      case 'Battery issue':
        return 'Battery';
      case 'Body damage':
        return 'Mechanic';
      default:
        return 'Mechanic';
    }
  }

  static String _defaultTitle(String type) {
    switch (type) {
      case 'Flat tire':
        return 'Flat tyre detected';
      case 'Broken light':
        return 'Broken light assembly';
      case 'Battery issue':
        return 'Battery health warning';
      default:
        return 'Visible body damage';
    }
  }

  static List<String> _defaultIndicators(String type) {
    switch (type) {
      case 'Flat tire':
        return const [
          'Tyre visibly deflated at the bottom',
          'Sidewall bulge or crack',
          'Nail or object embedded in the tread',
        ];
      case 'Broken light':
        return const [
          'Cracked headlamp or tail lamp lens',
          'Moisture inside the light housing',
          'Bulb not illuminating',
        ];
      case 'Battery issue':
        return const [
          'White or green corrosion on the terminal',
          'Loose or damaged terminal clamp',
          'Swollen battery case or warning light',
        ];
      default:
        return const [
          'Dent or deformation on a body panel',
          'Scratches with paint loss',
          'Misaligned panel gap',
        ];
    }
  }

  static List<String> _defaultTools(String type) {
    switch (type) {
      case 'Flat tire':
        return const [
          'Hydraulic jack',
          'Wheel spanner',
          'Tyre levers',
          'Portable inflator',
          'Wheel chocks',
        ];
      case 'Broken light':
        return const [
          'Trim removal kit',
          'Screwdriver set',
          'Multimeter',
          'Insulation tape',
        ];
      case 'Battery issue':
        return const [
          'Battery terminal brush',
          'Multimeter',
          'Insulated spanners',
          'Jump-start pack',
        ];
      default:
        return const [
          'Panel pry tools',
          'Dent puller',
          'Sanding block',
          'Paint matching kit',
        ];
    }
  }

  static List<String> _defaultParts(String type) {
    switch (type) {
      case 'Flat tire':
        return const ['Replacement tyre or tube', 'Valve stem', 'Wheel balancing weights'];
      case 'Broken light':
        return const ['Headlamp bulb or LED unit', 'Lamp housing gasket'];
      case 'Battery issue':
        return const ['Battery terminal clamp', 'Battery fuse', 'Replacement battery (if required)'];
      default:
        return const ['Body filler', 'Primer and paint', 'Panel clips'];
    }
  }

  static double _defaultLaborHours(String type) {
    switch (type) {
      case 'Flat tire':
        return 1.0;
      case 'Broken light':
        return 0.75;
      case 'Battery issue':
        return 0.5;
      default:
        return 2.0;
    }
  }

  static double _defaultPartsCost(String type) {
    switch (type) {
      case 'Flat tire':
        return 1200;
      case 'Broken light':
        return 650;
      case 'Battery issue':
        return 850;
      default:
        return 2500;
    }
  }

  static String _defaultPrepNote(String type) {
    switch (type) {
      case 'Flat tire':
        return 'Bring a matching tyre size and a portable inflator; check the spare wheel before departure.';
      case 'Broken light':
        return 'Confirm the bulb/LED part number for the vehicle before leaving the garage.';
      case 'Battery issue':
        return 'Test the alternator and battery load; carry a jump pack and terminal cleaning kit.';
      default:
        return 'Carry dent repair and paint matching materials; confirm the panel is safe to repair roadside.';
    }
  }
}
