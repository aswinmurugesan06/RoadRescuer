import 'package:flutter/material.dart';
import '../../../routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/rr_button.dart';
import '../../../widgets/rr_card.dart';

class PaymentResultScreen extends StatelessWidget {
  final bool success;
  final double? amount;
  final String? method;
  final String? transactionId;
  final String? receiptNumber;
  final String? paymentId;
  final String? requestId;

  const PaymentResultScreen({
    super.key,
    required this.success,
    this.amount,
    this.method,
    this.transactionId,
    this.receiptNumber,
    this.paymentId,
    this.requestId,
  });

  @override
  Widget build(BuildContext context) {
    final displayAmount = amount ?? 0.0;
    final displayMethod = _formatMethod(method ?? 'UPI');

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // Icon circle
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: (success ? AppColors.success : AppColors.danger)
                        .withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    success
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: success ? AppColors.success : AppColors.danger,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  success ? 'Payment Successful!' : 'Payment Failed',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  success
                      ? 'Your payment of ₹${displayAmount.toStringAsFixed(2)} has been confirmed and received.'
                      : 'We were unable to process your payment. Please try again or choose another method.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 32),

                if (success) ...[
                  RRCard(
                    child: Column(
                      children: [
                        if (transactionId != null) ...[
                          InfoRow(
                            label: 'Transaction ID',
                            value: transactionId!,
                          ),
                          const Divider(),
                        ],
                        if (receiptNumber != null) ...[
                          InfoRow(
                            label: 'Receipt No.',
                            value: receiptNumber!,
                          ),
                          const Divider(),
                        ],
                        InfoRow(
                          label: 'Amount Paid',
                          value: '₹${displayAmount.toStringAsFixed(2)}',
                        ),
                        const Divider(),
                        InfoRow(label: 'Payment Method', value: displayMethod),
                        const Divider(),
                        const InfoRow(label: 'Status', value: 'Completed'),
                      ],
                    ),
                  ),
                ],

                const Spacer(),

                if (success) ...[
                  RRButton(
                    label: 'View Detailed Receipt',
                    icon: Icons.receipt_long_rounded,
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.receipt,
                      arguments: {
                        if (paymentId != null) 'paymentId': paymentId,
                        if (requestId != null) 'requestId': requestId,
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (requestId != null) ...[
                    RRButton(
                      label: 'Rate & Review Specialist',
                      icon: Icons.star_rounded,
                      variant: RRButtonVariant.secondary,
                      onPressed: () => Navigator.pushNamed(
                        context,
                        AppRoutes.rating,
                        arguments: {'requestId': requestId},
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRoutes.customer,
                        (r) => false,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Back to Dashboard'),
                  ),
                ] else ...[
                  RRButton(
                    label: 'Retry Payment',
                    icon: Icons.refresh_rounded,
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, AppRoutes.payment),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatMethod(String method) {
    switch (method.toUpperCase()) {
      case 'UPI':
        return 'UPI';
      case 'CARD':
        return 'Credit/Debit Card';
      case 'CASH':
        return 'Cash';
      case 'NET_BANKING':
        return 'Net Banking';
      default:
        return method;
    }
  }
}
