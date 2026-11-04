import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../services/cost_estimation_service.dart';
import 'glass.dart';

/// Transparent, non-editable cost breakdown shared by customers and providers.
class CostBreakdownCard extends StatelessWidget {
  final CostEstimate estimate;
  final bool isProvider;

  const CostBreakdownCard({
    super.key,
    required this.estimate,
    this.isProvider = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isProvider
                      ? 'Provider estimate breakdown'
                      : 'Transparent cost breakdown',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'GST 18%',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
          if (!isProvider) ...[
            const SizedBox(height: 3),
            const Text(
              'Automatically calculated — no manual labour or parts input needed.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                height: 1.3,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ],
          const SizedBox(height: 10),
          _row('Emergency callout', '₹${estimate.baseCallout.toStringAsFixed(2)}'),
          _row(
            'Distance (${estimate.distanceKm.toStringAsFixed(1)} km)',
            '₹${estimate.distanceCharge.toStringAsFixed(2)}',
          ),
          _row(
            'Auto-allocated labour (${estimate.laborHours.toStringAsFixed(2)}h)',
            '₹${estimate.laborCharge.toStringAsFixed(2)}',
          ),
          _row(
            'Estimated spare parts',
            '₹${estimate.partsEstimate.toStringAsFixed(2)}',
          ),
          _row(
            'Vehicle multiplier (${estimate.vehicleType})',
            '×${estimate.vehicleMultiplier.toStringAsFixed(2)}',
            accent: true,
          ),
          Divider(
            color: isDark ? Colors.white12 : AppColors.dividerLight,
            height: 18,
          ),
          _row('Subtotal', '₹${estimate.subtotal.toStringAsFixed(2)}'),
          _row('GST 18%', '₹${estimate.taxAmount.toStringAsFixed(2)}'),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Estimated total',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '₹${estimate.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Expected range ₹${estimate.lowRange.toStringAsFixed(0)} – '
            '₹${estimate.highRange.toStringAsFixed(0)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool accent = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: accent ? AppColors.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}
