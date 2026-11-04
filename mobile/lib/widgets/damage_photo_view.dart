import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Renders a damage photo from either a Cloudinary URL or a Base64 data URL.
///
/// This lets a provider on another device/session see the customer's photo even
/// when Cloudinary is unavailable and the image was persisted as Base64.
class DamagePhotoView extends StatelessWidget {
  final String? imageUrl;
  final Uint8List? fallbackBytes;
  final double? width;
  final double height;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final String placeholderLabel;

  const DamagePhotoView({
    super.key,
    required this.imageUrl,
    this.fallbackBytes,
    this.width,
    this.height = 160,
    this.fit = BoxFit.cover,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.placeholderLabel = 'Damage photo not available',
  });

  @override
  Widget build(BuildContext context) {
    final image = _buildImage(context);

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: width ?? double.infinity,
        height: height,
        child: image,
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    final url = (imageUrl ?? '').trim();

    if (url.startsWith('data:image')) {
      final comma = url.indexOf(',');
      if (comma != -1) {
        try {
          final bytes = base64Decode(url.substring(comma + 1));
          return _memory(bytes);
        } catch (_) {
          return _placeholder();
        }
      }
      return _placeholder();
    }

    if (url.startsWith('http')) {
      return Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _placeholder(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _loading();
        },
      );
    }

    final bytes = fallbackBytes;
    if (bytes != null && bytes.isNotEmpty) return _memory(bytes);

    return _placeholder();
  }

  Widget _memory(Uint8List bytes) {
    return Image.memory(
      bytes,
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }

  Widget _loading() {
    return _base(
      const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _placeholder() {
    return _base(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.image_search_rounded,
            size: 26,
            color: AppColors.primary,
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              placeholderLabel,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9.5,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _base(Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: borderRadius,
      ),
      child: Center(child: child),
    );
  }
}
