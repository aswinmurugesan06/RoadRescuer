import 'package:flutter/material.dart';

/// Official RoadRescue app logo widget.
/// Renders the official approved logo image asset with strict aspect ratio preservation
/// and responsive constraints.
class AppLogo extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool withShadow;

  const AppLogo({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.withShadow = false,
  });

  /// Prominent centered logo for Splash screen (~180-220dp)
  const AppLogo.splash({
    super.key,
    this.width,
    this.height = 190,
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.withShadow = true,
  });

  /// Medium logo for Auth screens (Login, Register, Welcome) (~56-72dp)
  const AppLogo.authHeader({
    super.key,
    this.width,
    this.height = 60,
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.withShadow = false,
  });

  /// Small compact brand mark for AppBars / Headers (~28-36dp)
  const AppLogo.appBar({
    super.key,
    this.width,
    this.height = 32,
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.withShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = Image.asset(
      'assets/images/logo.png',
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          'assets/images/logo.jpg',
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
              color: Colors.black.withOpacity(0.3),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}
