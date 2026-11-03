import 'package:flutter/material.dart';

/// Official RoadRescue brand logo.
///
/// Three assets are used:
/// - `logo_icon.png`       square mark for app bars
/// - `logo_wordmark_dark.png` horizontal mark for light auth screens
/// - `logo_stacked_light.png` stacked mark for the dark splash/welcome screens
class AppLogo extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool withShadow;
  final String _asset;

  const AppLogo({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.withShadow = false,
  }) : _asset = 'assets/images/logo_stacked_dark.png';

  /// Prominent centered logo for the dark splash screen.
  const AppLogo.splash({
    super.key,
    this.width,
    this.height = 190,
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.withShadow = true,
  }) : _asset = 'assets/images/logo_stacked_light.png';

  /// Horizontal wordmark for light auth screens.
  const AppLogo.authHeader({
    super.key,
    this.width,
    this.height = 52,
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.withShadow = false,
  }) : _asset = 'assets/images/logo_wordmark_dark.png';

  /// Compact square mark for app bars and headers.
  const AppLogo.appBar({
    super.key,
    this.width,
    this.height = 32,
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.withShadow = false,
  }) : _asset = 'assets/images/logo_icon.png';

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = Image.asset(
      _asset,
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          'assets/images/logo.png',
          width: width,
          height: height,
          fit: fit,
        );
      },
    );

    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    if (withShadow) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}
