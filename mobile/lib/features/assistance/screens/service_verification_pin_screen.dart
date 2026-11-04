import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/rr_button.dart';

class ServiceVerificationPinScreen extends StatelessWidget {
  final String? pin;

  const ServiceVerificationPinScreen({super.key, this.pin});

  String get _pin =>
      (pin != null && pin!.trim().length == 4) ? pin!.trim() : '4829';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Start PIN'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_rounded, size: 40, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              const Text(
                'Security Verification PIN',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Share this PIN with the technician ONLY after they arrive in person at your vehicle.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondaryLight),
              ),
              const SizedBox(height: 40),

              // Large 4-digit PIN Box
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _pin.split('').map((digit) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 60,
                    height: 72,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cardDark : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        digit,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 40),

              // Mock QR Container
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.dividerLight),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.qr_code_2_rounded, size: 100, color: Colors.black87),
                    SizedBox(height: 6),
                    Text(
                      'Provider can also scan this QR',
                      style: TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const Spacer(),

              RRButton(
                label: 'Back to Assistance Tracking',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
