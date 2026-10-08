import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/service_request_model.dart';
import 'rr_status_badge.dart';

class RequestCardWidget extends StatelessWidget {
  final ServiceRequestModel request;
  final VoidCallback? onTap;

  const RequestCardWidget({super.key, required this.request, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Material(
      color: isDark ? AppColors.cardDark : AppColors.cardLight,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(request.serviceTypeIcon, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.serviceType,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          request.vehicleModel,
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  RRStatusBadge(
                    label: request.status.label,
                    color: Color(request.status.colorValue),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(color: isDark ? AppColors.dividerDark : AppColors.dividerLight, height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.build_circle_outlined, size: 14, color: textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      request.problem,
                      style: TextStyle(fontSize: 13, color: textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 14, color: textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      request.location,
                      style: TextStyle(fontSize: 13, color: textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (request.totalAmount > 0)
                    Text(
                      '₹${request.totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Provider Card Widget ──────────────────────────────────────────────
class ProviderCardWidget extends StatelessWidget {
  final String name;
  final String type;
  final double rating;
  final int totalJobs;
  final double distanceKm;
  final String eta;
  final VoidCallback? onSelect;

  const ProviderCardWidget({
    super.key,
    required this.name,
    required this.type,
    required this.rating,
    required this.totalJobs,
    required this.distanceKm,
    required this.eta,
    this.onSelect,
  });

  String get _typeIcon {
    switch (type) {
      case 'Mechanic': return '🔧';
      case 'Puncture': return '🛞';
      case 'Tow': return '🚚';
      default: return '🔧';
    }
  }

  Color get _typeColor {
    switch (type) {
      case 'Mechanic': return AppColors.mechanic;
      case 'Puncture': return AppColors.puncture;
      case 'Tow': return AppColors.tow;
      default: return AppColors.mechanic;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.dividerDark : AppColors.dividerLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _typeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text(_typeIcon, style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: AppColors.starRating),
                        const SizedBox(width: 3),
                        Text('$rating', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 4),
                        Text('($totalJobs jobs)', style: TextStyle(fontSize: 12, color: textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${distanceKm}km', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  Text(eta, style: TextStyle(fontSize: 12, color: textSecondary)),
                ],
              ),
            ],
          ),
          if (onSelect != null) ...[
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onSelect,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Select Provider'),
            ),
          ],
        ],
      ),
    );
  }
}
