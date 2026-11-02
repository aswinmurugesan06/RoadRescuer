import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/pricing_estimate_model.dart';
import 'rr_card.dart';

/// Reusable pricing breakdown widget displaying real-time dynamic cost estimation.
class RRPricingBreakdownCard extends StatefulWidget {
  final PricingEstimateModel? estimate;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;

  const RRPricingBreakdownCard({
    super.key,
    this.estimate,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
  });

  @override
  State<RRPricingBreakdownCard> createState() => _RRPricingBreakdownCardState();
}

class _RRPricingBreakdownCardState extends State<RRPricingBreakdownCard> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RRCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cost Estimate',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (widget.estimate != null)
                      Text(
                        widget.estimate!.matchedTierLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.estimate != null && widget.estimate!.isProvisional)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.warning.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.warning,
                        size: 12,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Provisional',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Body content depending on state
          if (widget.isLoading) _buildLoadingState(isDark),
          if (!widget.isLoading && widget.errorMessage != null)
            _buildErrorState(isDark),
          if (!widget.isLoading &&
              widget.errorMessage == null &&
              widget.estimate != null)
            _buildEstimateContent(isDark, widget.estimate!),
          if (!widget.isLoading &&
              widget.errorMessage == null &&
              widget.estimate == null)
            _buildEmptyState(isDark),
        ],
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Calculating live pricing estimate...',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.danger, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.errorMessage ?? 'Estimate unavailable at this time',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'You may still proceed with your request. Pricing will be verified directly by your assigned service provider.',
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          if (widget.onRetry != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: widget.onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text('Retry Estimate',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'Pricing estimate will appear once location is locked.',
        style: TextStyle(
          fontSize: 12,
          color: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
        ),
      ),
    );
  }

  Widget _buildEstimateContent(bool isDark, PricingEstimateModel est) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Total Display Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surfaceDark
                : AppColors.primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    est.isProvisional
                        ? 'PROVISIONAL ESTIMATE'
                        : 'ESTIMATED TOTAL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Incl. 18% GST',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? AppColors.textHintDark
                          : AppColors.textHintLight,
                    ),
                  ),
                ],
              ),
              Text(
                est.formattedTotal,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),

        // Provisional Notice Banner
        if (est.isProvisional) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.warning.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.near_me_outlined,
                  size: 16,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    est.note.isNotEmpty
                        ? est.note
                        : 'Provider travel charges will be calculated after provider assignment.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 12),

        // Expandable Itemized Breakdown Header
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Itemized Rate Breakdown',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ],
            ),
          ),
        ),

        if (_isExpanded) ...[
          const SizedBox(height: 6),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Base Service Labor
          _buildBreakdownRow(
            label: 'Base Service / Labor',
            value: est.formattedBaseLabor,
            isDark: isDark,
          ),

          // Distance / Travel Charge
          _buildBreakdownRow(
            label: 'Travel / Distance Charge',
            value: est.distanceStatus == 'NO_PROVIDER_AVAILABLE_BASE_ONLY'
                ? 'Pending match'
                : (est.distanceCharge > 0
                    ? est.formattedDistanceCharge
                    : '₹0.00 (Included)'),
            sublabel: est.distanceStatus == 'NO_PROVIDER_AVAILABLE_BASE_ONLY'
                ? null
                : (est.distanceCharge > 0
                    ? '${est.billableDistanceKm} km billable @ ₹${est.perKmCharge}/km (${est.includedDistanceKm} km incl.)'
                    : 'Within ${est.includedDistanceKm} km included radius'),
            isDark: isDark,
          ),

          // Additional Charges
          if (est.hasAdditionalCharges)
            _buildBreakdownRow(
              label: 'Additional Surcharges',
              value: est.formattedAdditionalCharges,
              isDark: isDark,
            ),

          // Subtotal
          _buildBreakdownRow(
            label: 'Subtotal',
            value: est.formattedSubtotal,
            isDark: isDark,
            isBold: true,
          ),

          // Tax
          _buildBreakdownRow(
            label: 'GST (${(est.taxRate * 100).toStringAsFixed(0)}%)',
            value: est.formattedTax,
            isDark: isDark,
          ),
        ],

        const SizedBox(height: 10),

        // Legal & Final Invoice Reassurance Disclaimer
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.verified_user_outlined,
              size: 13,
              color: isDark
                  ? AppColors.textHintDark
                  : AppColors.textHintLight,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'This estimate is transparent and indicative. Your final bill will be verified on site by the provider without duplicate tax.',
                style: TextStyle(
                  fontSize: 10,
                  height: 1.3,
                  color: isDark
                      ? AppColors.textHintDark
                      : AppColors.textHintLight,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBreakdownRow({
    required String label,
    required String value,
    String? sublabel,
    required bool isDark,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                  color: isDark
                      ? (isBold
                          ? AppColors.textPrimaryDark
                          : AppColors.textSecondaryDark)
                      : (isBold
                          ? AppColors.textPrimaryLight
                          : AppColors.textSecondaryLight),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
                  color: isBold ? AppColors.primary : null,
                ),
              ),
            ],
          ),
          if (sublabel != null) ...[
            const SizedBox(height: 1),
            Text(
              sublabel,
              style: TextStyle(
                fontSize: 10,
                color: isDark
                    ? AppColors.textHintDark
                    : AppColors.textHintLight,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
