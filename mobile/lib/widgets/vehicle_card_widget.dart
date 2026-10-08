import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/vehicle_model.dart';

class VehicleCardWidget extends StatelessWidget {
  final VehicleModel vehicle;
  final VoidCallback? onTap;
  final VoidCallback? onSetDefault;
  final bool compact;

  const VehicleCardWidget({
    super.key,
    required this.vehicle,
    this.onTap,
    this.onSetDefault,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final border = isDark ? AppColors.dividerDark : AppColors.dividerLight;

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(compact ? 12 : 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: vehicle.isDefault ? AppColors.primary.withOpacity(0.4) : border,
              width: vehicle.isDefault ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // Vehicle icon container
              Container(
                width: compact ? 44 : 52,
                height: compact ? 44 : 52,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(vehicle.typeIcon, style: TextStyle(fontSize: compact ? 22 : 26)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            vehicle.displayName,
                            style: TextStyle(
                              fontSize: compact ? 14 : 15,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (vehicle.isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Default',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      vehicle.plateNumber,
                      style: TextStyle(
                        fontSize: compact ? 12 : 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 4),
                      Text(
                        [
                          vehicle.type,
                          if (vehicle.year != null && vehicle.year!.isNotEmpty) vehicle.year!,
                          if (vehicle.color != null && vehicle.color!.isNotEmpty) vehicle.color!,
                        ].join(' • '),
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              if (!compact)
                Icon(Icons.chevron_right_rounded, color: textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
