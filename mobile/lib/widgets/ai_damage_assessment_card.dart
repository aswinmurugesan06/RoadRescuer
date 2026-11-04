import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme/app_colors.dart';
import '../services/ai_damage_service.dart';
import '../services/cost_estimation_service.dart';
import 'damage_photo_view.dart';
import 'glass.dart';

/// Customer-facing photo upload + AI damage assessment card.
///
/// Used on the Request Assistance and Dynamic Cost Estimator screens.
class AiDamageAssessmentCard extends StatefulWidget {
  final String vehicleType;
  final String? selectedCategory;
  final ValueChanged<AiDamageAssessment>? onAssessment;
  final CostEstimate? estimate;

  const AiDamageAssessmentCard({
    super.key,
    required this.vehicleType,
    this.selectedCategory,
    this.onAssessment,
    this.estimate,
  });

  @override
  State<AiDamageAssessmentCard> createState() =>
      _AiDamageAssessmentCardState();
}

class _AiDamageAssessmentCardState extends State<AiDamageAssessmentCard> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _imageBytes;
  AiDamageAssessment? _assessment;
  bool _isAnalyzing = false;
  String? _error;

  Future<void> _pickImage(ImageSource source) async {
    if (_isAnalyzing) return;
    setState(() => _error = null);

    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 65,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _assessment = null;
        _isAnalyzing = true;
      });

      final assessment = await AiDamageService.assess(
        imageBytes: bytes,
        vehicleType: widget.vehicleType,
        fallbackCategory: widget.selectedCategory,
      );
      if (!mounted) return;

      setState(() {
        _assessment = assessment;
        _isAnalyzing = false;
      });
      widget.onAssessment?.call(assessment);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _error = 'Could not analyse that image. Please try another photo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final assessment = _assessment;
    final result = assessment?.result;

    return GlassCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const GlassIconBox(
                icon: Icons.auto_awesome_rounded,
                size: 40,
                iconSize: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'AI Visual Damage Assessment',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'BETA',
                            style: TextStyle(
                              fontSize: 7.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Photo → Gemini Vision → cost & mechanic prep',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_imageBytes != null) ...[
            Stack(
              children: [
                DamagePhotoView(
                  imageUrl: _assessment?.imageUrl,
                  fallbackBytes: _imageBytes,
                  height: 160,
                  borderRadius: BorderRadius.circular(14),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 11,
                          color: Colors.white,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Gemini Vision',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: _photoButton(
                  icon: Icons.camera_alt_rounded,
                  label: 'Take Photo',
                  onTap: _isAnalyzing
                      ? null
                      : () => _pickImage(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _photoButton(
                  icon: Icons.photo_library_rounded,
                  label: 'Upload Photo',
                  onTap: _isAnalyzing
                      ? null
                      : () => _pickImage(ImageSource.gallery),
                ),
              ),
            ],
          ),
          if (_isAnalyzing) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(
              minHeight: 3,
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
            const SizedBox(height: 7),
            const Text(
              'Analysing the photo with Gemini Vision…',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 15,
                  color: AppColors.danger,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.danger,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (result != null) ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.damageTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? Colors.white
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${result.detectedType} • ${result.mappedCategory}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _severityBadge(result.severity),
              ],
            ),
            const SizedBox(height: 10),
            _chipWrap(
              result.visibleIndicators,
              color: AppColors.danger,
            ),
            if (result.requiredTools.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'REQUIRED TOOLS',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 5),
              _chipWrap(
                result.requiredTools,
                color: AppColors.primary,
                icon: Icons.handyman_rounded,
              ),
            ],
            if (result.recommendedParts.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'RECOMMENDED SPARE PARTS',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 5),
              _chipWrap(
                result.recommendedParts,
                color: AppColors.tertiary,
                icon: Icons.settings_suggest_rounded,
              ),
            ],
            const SizedBox(height: 8),
            if (result.isFallback) ...[
              const SizedBox(height: 6),
              const Text(
                'Offline smart analysis • connect Gemini for live vision.',
                style: TextStyle(
                  fontSize: 8.5,
                  color: AppColors.textHintLight,
                ),
              ),
            ],
          ],
          if (widget.estimate != null) ...[
            const SizedBox(height: 12),
            _estimateSummary(widget.estimate!),
          ],
        ],
      ),
    );
  }

  Widget _photoButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: AppColors.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _severityBadge(String severity) {
    final color = switch (severity) {
      'Severe' => AppColors.danger,
      'Low' => AppColors.success,
      _ => AppColors.warning,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            severity.toUpperCase(),
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipWrap(
    List<String> items, {
    required Color color,
    IconData icon = Icons.check_circle_rounded,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: items.map((item) {
            return ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.14)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 11, color: color),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 9,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _estimateSummary(CostEstimate estimate) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0045D1), Color(0xFF1A5CFF)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calculate_rounded,
                size: 14,
                color: Colors.white70,
              ),
              const SizedBox(width: 5),
              const Expanded(
                child: Text(
                  'UPDATED DYNAMIC ESTIMATE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Colors.white70,
                  ),
                ),
              ),
              Text(
                '${estimate.laborHours.toStringAsFixed(1)}h labour',
                style: const TextStyle(fontSize: 8, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '₹${estimate.lowRange.toStringAsFixed(0)} – ₹${estimate.highRange.toStringAsFixed(0)}',
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: Colors.white,
            ),
          ),
          Text(
            'Most likely ₹${estimate.total.toStringAsFixed(0)} incl. GST • '
            '${estimate.issueCategory}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
