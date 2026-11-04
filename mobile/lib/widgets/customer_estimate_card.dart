import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/service_request_model.dart';

/// Shows the customer's pre-booking estimate to the provider.
///
/// The figures are persisted on the request so both roles see the same initial
/// expectation. Final invoice values can still be edited in Create Bill.
class CustomerEstimateCard extends StatelessWidget {
  final ServiceRequestModel request;

  const CustomerEstimateCard({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final hasEstimate = request.totalAmount > 0 ||
        request.estimatedDistanceCharge != null ||
        request.estimatedLaborCharge != null ||
        (request.estimatedPartsCost ?? 0) > 0;
    if (!hasEstimate) return const SizedBox.shrink();

    final distanceKm = request.estimatedDistanceKm;
    final distanceCharge = request.estimatedDistanceCharge ?? 0;
    final laborHours = request.estimatedLaborHours ?? 0;
    final laborCharge = request.estimatedLaborCharge ?? 0;
    final parts = request.estimatedPartsCost ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.request_quote_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'Customer pre-booking estimate',
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
                '₹${request.totalAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _row(
            'Distance',
            distanceKm == null
                ? 'Auto'
                : '${distanceKm.toStringAsFixed(1)} km',
            '₹${distanceCharge.toStringAsFixed(0)}',
          ),
          _row(
            'Auto labour',
            '${laborHours.toStringAsFixed(2)}h',
            '₹${laborCharge.toStringAsFixed(0)}',
          ),
          _row(
            'Estimated parts',
            '',
            '₹${parts.toStringAsFixed(0)}',
          ),
          const SizedBox(height: 5),
          const Text(
            'Customer expectation before inspection. Adjust final invoice items in Create Bill.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              height: 1.3,
              color: AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String sub, String amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              sub.isEmpty ? label : '$label • $sub',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amount,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
