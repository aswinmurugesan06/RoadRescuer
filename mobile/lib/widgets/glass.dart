import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Frosted glass surface used across the redesigned app.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.borderRadius = 20,
    this.onTap,
    this.color,
    this.borderColor,
    this.blur = 18,
    this.boxShadow,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double blur;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(borderRadius);
    final effectiveColor = color ??
        (isDark
            ? AppColors.cardDark.withOpacity(0.82)
            : Colors.white.withOpacity(0.78));
    final effectiveBorder = borderColor ??
        (isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.9));

    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveColor,
        borderRadius: radius,
        border: Border.all(color: effectiveBorder),
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: (isDark ? Colors.black : const Color(0xFF0F172A))
                    .withOpacity(isDark ? 0.2 : 0.05),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
      ),
      child: child,
    );

    final frosted = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: content,
      ),
    );

    if (onTap == null) {
      return Padding(padding: margin, child: frosted);
    }

    return Padding(
      padding: margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: frosted,
        ),
      ),
    );
  }
}

/// Small frosted chip/pill for secondary information.
class GlassPill extends StatelessWidget {
  const GlassPill({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.borderRadius = 14,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ??
            (isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.white.withOpacity(0.68)),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.white.withOpacity(0.92),
        ),
      ),
      child: child,
    );
  }
}

class GlassIconBox extends StatelessWidget {
  const GlassIconBox({
    super.key,
    required this.icon,
    this.color = AppColors.primary,
    this.size = 44,
    this.iconSize = 22,
    this.background,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(
          color: color.withOpacity(0.14),
        ),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

class GlassSectionHeading extends StatelessWidget {
  const GlassSectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

/// Primary gradient CTA used for emergency / payment actions.
class GradientActionButton extends StatelessWidget {
  const GradientActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.colors,
    this.icon,
    this.height = 52,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final List<Color> colors;
  final IconData? icon;
  final double height;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: isLoading ? null : onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: colors.first.withOpacity(0.3),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Plus Jakarta Sans',
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class GlassNavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const GlassNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

/// Floating frosted bottom navigation bar.
class GlassBottomNav extends StatelessWidget {
  const GlassBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<GlassNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 66,
            decoration: BoxDecoration(
              color: (isDark ? AppColors.cardDark : Colors.white)
                  .withOpacity(isDark ? 0.86 : 0.82),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.white.withOpacity(0.95),
              ),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : const Color(0xFF0F172A))
                      .withOpacity(isDark ? 0.35 : 0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              children: List.generate(items.length, (index) {
                final item = items[index];
                final selected = index == currentIndex;
                final muted = isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight;
                return Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => onTap(index),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary.withOpacity(0.11)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            selected ? item.selectedIcon : item.icon,
                            size: 22,
                            color: selected ? AppColors.primary : muted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'Plus Jakarta Sans',
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w600,
                            color: selected ? AppColors.primary : muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft ambient background used behind the glass screens.
class GlassBackground extends StatelessWidget {
  const GlassBackground({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -100,
            child: _orb(
              isDark ? AppColors.primary.withOpacity(0.22) : const Color(0xFFBFDBFE),
              260,
            ),
          ),
          Positioned(
            top: 260,
            right: -120,
            child: _orb(
              isDark ? AppColors.secondary.withOpacity(0.14) : const Color(0xFFE0E7FF),
              300,
            ),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: _orb(
              isDark ? AppColors.tertiary.withOpacity(0.14) : const Color(0xFFE0F2FE),
              260,
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }

  Widget _orb(Color color, double size) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 36, sigmaY: 36),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.65),
          ),
        ),
      ),
    );
  }
}
