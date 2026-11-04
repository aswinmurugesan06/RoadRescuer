import 'package:flutter/material.dart';

/// Official multicolor Google "G" logo.
///
/// The asset is transparent so it can sit on white or light glass surfaces.
class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/google_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Google',
      errorBuilder: (_, __, ___) => SizedBox(
        width: size,
        height: size,
        child: const Center(
          child: Text(
            'G',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Color(0xFF4285F4),
            ),
          ),
        ),
      ),
    );
  }
}
