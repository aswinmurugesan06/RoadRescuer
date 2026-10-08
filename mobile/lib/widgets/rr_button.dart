import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/constants/app_constants.dart';

enum RRButtonVariant { primary, secondary, danger, outline, ghost }

class RRButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final RRButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;
  final double? height;
  final double? fontSize;

  const RRButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = RRButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
    this.height,
    this.fontSize,
  });

  const RRButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
    this.height,
    this.fontSize,
  }) : variant = RRButtonVariant.secondary;

  const RRButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
    this.height,
    this.fontSize,
  }) : variant = RRButtonVariant.danger;

  const RRButton.outline({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
    this.height,
    this.fontSize,
  }) : variant = RRButtonVariant.outline;

  @override
  Widget build(BuildContext context) {
    final effectiveHeight = height ?? AppConstants.buttonHeightMD;
    final effectiveFontSize = fontSize ?? 16.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(_getFgColor()),
            ),
          )
        else ...[
          if (icon != null) ...[
            Icon(icon, size: 20, color: _getFgColor()),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: effectiveFontSize,
              fontWeight: FontWeight.w600,
              color: _getFgColor(),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ],
    );

    switch (variant) {
      case RRButtonVariant.outline:
        return SizedBox(
          width: fullWidth ? double.infinity : null,
          height: effectiveHeight,
          child: OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: isDark ? AppColors.primaryLight : AppColors.primary, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMD)),
            ),
            child: child,
          ),
        );
      case RRButtonVariant.ghost:
        return SizedBox(
          width: fullWidth ? double.infinity : null,
          height: effectiveHeight,
          child: TextButton(
            onPressed: isLoading ? null : onPressed,
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMD)),
            ),
            child: child,
          ),
        );
      default:
        return SizedBox(
          width: fullWidth ? double.infinity : null,
          height: effectiveHeight,
          child: ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: _getBgColor(isDark),
              foregroundColor: _getFgColor(),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMD)),
              elevation: 0,
              disabledBackgroundColor: AppColors.dividerLight,
            ),
            child: child,
          ),
        );
    }
  }

  Color _getBgColor(bool isDark) {
    switch (variant) {
      case RRButtonVariant.primary:
        return isDark ? AppColors.primaryLight : AppColors.primary;
      case RRButtonVariant.secondary:
        return isDark ? AppColors.secondaryLight : AppColors.secondary;
      case RRButtonVariant.danger:
        return AppColors.danger;
      default:
        return isDark ? AppColors.primaryLight : AppColors.primary;
    }
  }

  Color _getFgColor() {
    switch (variant) {
      case RRButtonVariant.outline:
      case RRButtonVariant.ghost:
        return AppColors.primary;
      default:
        return Colors.white;
    }
  }
}
