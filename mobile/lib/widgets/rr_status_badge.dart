import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class RRStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  final double? fontSize;

  const RRStatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.filled = false,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color : color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize ?? 12,
          fontWeight: FontWeight.w600,
          color: filled ? Colors.white : color,
        ),
      ),
    );
  }
}

// ── Provider Availability Badge ───────────────────────────────────────
class AvailabilityBadge extends StatelessWidget {
  final bool isAvailable;
  const AvailabilityBadge({super.key, required this.isAvailable});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isAvailable ? AppColors.available : AppColors.offline,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          isAvailable ? 'Available' : 'Offline',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isAvailable ? AppColors.available : AppColors.offline,
          ),
        ),
      ],
    );
  }
}

// ── Star Rating ───────────────────────────────────────────────────────
class StarRating extends StatelessWidget {
  final double rating;
  final int count;
  final double size;

  const StarRating({super.key, required this.rating, this.count = 0, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: size, color: AppColors.starRating),
        const SizedBox(width: 3),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(fontSize: size - 1, fontWeight: FontWeight.w700),
        ),
        if (count > 0) ...[
          const SizedBox(width: 3),
          Text(
            '($count)',
            style: TextStyle(
              fontSize: size - 2,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ],
    );
  }
}

typedef RRStarRating = StarRating;
