import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/service_request_model.dart';
import '../../../routes/app_routes.dart';
import '../../../services/api_client.dart';
import '../../../services/rating_service.dart';
import '../../../widgets/rr_button.dart';
import '../../../widgets/rr_card.dart';
import '../../../widgets/rr_status_badge.dart';

class RatingScreen extends StatefulWidget {
  final ServiceRequestModel? request;
  final String? requestId;

  const RatingScreen({
    super.key,
    this.request,
    this.requestId,
  });

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _ratingScore = 5;
  final TextEditingController _reviewController = TextEditingController();
  final Set<String> _selectedTags = {};
  bool _isSubmitting = false;

  static const List<String> _feedbackTags = [
    '⚡ Fast Arrival',
    '🔧 Skilled Mechanic',
    '💰 Fair Pricing',
    '🤝 Polite & Helpful',
    '🛡️ Safe & Professional',
    '🚗 Smooth Repair',
  ];

  String get _effectiveRequestId =>
      widget.request?.id ?? widget.requestId ?? '';

  String get _ratingLabel {
    switch (_ratingScore) {
      case 1:
        return 'Needs Significant Improvement';
      case 2:
        return 'Below Expectations';
      case 3:
        return 'Average / Satisfactory';
      case 4:
        return 'Great Experience!';
      case 5:
      default:
        return 'Outstanding & Highly Recommended!';
    }
  }

  Color get _ratingColor {
    switch (_ratingScore) {
      case 1:
      case 2:
        return AppColors.danger;
      case 3:
        return AppColors.warning;
      case 4:
      case 5:
      default:
        return AppColors.starRating;
    }
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    final reqId = _effectiveRequestId;
    if (reqId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Missing service request ID to submit rating.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final tagsText = _selectedTags.isNotEmpty
          ? '\n\nHighlights: ${_selectedTags.join(', ')}'
          : '';
      final fullReview = '${_reviewController.text.trim()}$tagsText'.trim();

      await RatingService.submitRating(
        requestId: reqId,
        score: _ratingScore,
        review: fullReview.isNotEmpty ? fullReview : null,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you! Your rating & review has been submitted.'),
          backgroundColor: AppColors.success,
        ),
      );

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.customer,
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      final msg = e is ApiException ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit rating: $msg'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final providerName = widget.request?.providerName ?? 'Roadside Specialist';
    final serviceType = widget.request?.serviceType ?? 'Roadside Assistance';
    final vehicleModel = widget.request?.vehicleModel ?? 'Vehicle';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Your Experience'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Top Summary Header ──────────────────────────────
              RRCard(
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.engineering_rounded,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            providerName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$serviceType • $vehicleModel',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const RRStatusBadge(
                      label: 'COMPLETED',
                      color: AppColors.success,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Star Selector ──────────────────────────────────
              Text(
                'How was the service?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starIndex = index + 1;
                  final isSelected = starIndex <= _ratingScore;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _ratingScore = starIndex);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: AnimatedScale(
                        scale: isSelected ? 1.15 : 1.0,
                        duration: const Duration(milliseconds: 180),
                        child: Icon(
                          isSelected
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: isSelected
                              ? _ratingColor
                              : Colors.grey.withOpacity(0.4),
                          size: 44,
                        ),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 12),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _ratingLabel,
                  key: ValueKey<int>(_ratingScore),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _ratingColor,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Quick Compliment Chips ─────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'What went well?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _feedbackTags.map((tag) {
                  final isSelected = _selectedTags.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: isSelected,
                    selectedColor: AppColors.primary.withOpacity(0.18),
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? AppColors.primary : null,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // ── Written Review Text Area ───────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Write a review (optional)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reviewController,
                maxLines: 4,
                maxLength: 1000,
                decoration: InputDecoration(
                  hintText:
                      'Share details of your experience to help other drivers...',
                  filled: true,
                  fillColor: isDark
                      ? AppColors.surfaceDark
                      : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark
                          ? Colors.white12
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Submit Button ──────────────────────────────────
              RRButton(
                label: 'Submit Rating & Review',
                icon: Icons.send_rounded,
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _submitRating,
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.customer,
                    (r) => false,
                  );
                },
                child: const Text(
                  'Skip for now',
                  style: TextStyle(
                    color: AppColors.textSecondaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
