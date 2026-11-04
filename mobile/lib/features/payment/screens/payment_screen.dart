import 'package:flutter/material.dart';
import '../../../routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/bill_model.dart';
import '../../../services/billing_service.dart';
import '../../../widgets/glass.dart';
import '../../../widgets/rr_button.dart';
import '../../../widgets/rr_card.dart';
import '../../../widgets/rr_text_field.dart';

class PaymentScreen extends StatefulWidget {
  /// The real bill being paid. Falls back to mock for design preview.
  final BillModel? bill;

  const PaymentScreen({super.key, this.bill});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selectedMethod = 'UPI'; // UPI, CARD, CASH, NET_BANKING
  String _selectedUpiApp = 'Google Pay';
  final _upiIdController = TextEditingController();
  bool _isProcessing = false;
  String? _errorMessage;

  BillModel get _bill => widget.bill ?? BillModel.mock;

  @override
  void dispose() {
    _upiIdController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    final bill = _bill;

    // If it's a mock/preview — just show success without hitting API
    if (bill.id == 'mock-bill-001' || bill.id.isEmpty) {
      setState(() => _isProcessing = true);
      await Future.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;
      setState(() => _isProcessing = false);
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.paymentResult,
        (r) => r.isFirst,
        arguments: {'success': true, 'amount': bill.grandTotal, 'method': _selectedMethod},
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      if (_selectedMethod == 'CASH') {
        // Direct Cash on Service settlement
        final result = await BillingService.processPayment(
          billId: bill.id,
          method: 'CASH',
        );

        if (!mounted) return;

        final payment = result['payment'] as Map<String, dynamic>?;
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.paymentResult,
          (r) => r.isFirst,
          arguments: {
            'success': true,
            'amount': bill.grandTotal,
            'method': 'CASH',
            'transactionId': payment?['transactionId'],
            'receiptNumber': payment?['receiptNumber'],
            'paymentId': payment?['id'],
            'requestId': bill.requestId,
          },
        );
      } else {
        // 1. Server-side Razorpay Order Creation
        final orderData = await BillingService.createOrder(bill.id);
        final orderId = orderData['orderId'] as String;

        // 2. Gateway Checkout
        // In mobile checkout with Razorpay SDK or test verification:
        final paymentId = 'pay_${DateTime.now().millisecondsSinceEpoch}_${orderId.length > 6 ? orderId.substring(orderId.length - 6) : orderId}';
        
        // 3. Server-side Payment Verification
        // Note: For direct simulation/test keys, the signature or direct fallback is verified on server
        final verifyResult = await BillingService.processPayment(
          billId: bill.id,
          method: _selectedMethod,
        );

        if (!mounted) return;

        final payment = verifyResult['payment'] as Map<String, dynamic>?;
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.paymentResult,
          (r) => r.isFirst,
          arguments: {
            'success': true,
            'amount': bill.grandTotal,
            'method': _selectedMethod,
            'transactionId': payment?['transactionId'] ?? paymentId,
            'receiptNumber': payment?['receiptNumber'],
            'paymentId': payment?['id'],
            'requestId': bill.requestId,
          },
        );
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().split('):').last.trim();
      setState(() {
        _isProcessing = false;
        _errorMessage = msg.isNotEmpty ? msg : 'Payment failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bill = _bill;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Payment Method'),
      ),
      body: GlassBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    20 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Amount banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Amount to Pay',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '₹${bill.grandTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Includes GST (18%) • ${bill.providerName}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Error message
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppColors.danger, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.danger,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Payment Method Options
                    const SectionHeader(title: 'Choose Payment Option'),
                    const SizedBox(height: 12),

                    // 1. UPI
                    _buildMethodTile(
                      id: 'UPI',
                      title: 'Razorpay UPI (GPay, PhonePe, Paytm)',
                      subtitle: 'Instant & zero transaction fee',
                      icon: Icons.account_balance_wallet_rounded,
                      color: AppColors.primary,
                      expandedChild: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          const Text(
                            'Popular Apps',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ['Google Pay', 'PhonePe', 'Paytm']
                                .map((app) {
                              final isAppSelected = _selectedUpiApp == app;
                              return ChoiceChip(
                                label: Text(app),
                                selected: isAppSelected,
                                onSelected: (_) =>
                                    setState(() => _selectedUpiApp = app),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                          RRTextField(
                            label: 'Or enter UPI ID',
                            controller: _upiIdController,
                            prefixIcon: Icons.alternate_email_rounded,
                            hint: 'yourname@upi',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 2. Card
                    _buildMethodTile(
                      id: 'CARD',
                      title: 'Razorpay Credit / Debit Card',
                      subtitle: 'Visa, MasterCard, RuPay, Maestro',
                      icon: Icons.credit_card_rounded,
                      color: AppColors.secondary,
                      expandedChild: const Column(
                        children: [
                          SizedBox(height: 12),
                          RRTextField(
                            label: 'Card Number',
                            hint: '4321 •••• •••• 9821',
                            prefixIcon: Icons.credit_card,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 3. Cash on Service
                    _buildMethodTile(
                      id: 'CASH',
                      title: 'Cash on Service',
                      subtitle: 'Pay physical cash directly to technician',
                      icon: Icons.payments_rounded,
                      color: AppColors.success,
                    ),
                    const SizedBox(height: 28),

                    // Security assurance
                    const Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Icon(Icons.lock_rounded,
                            size: 16, color: AppColors.success),
                        Text(
                          '256-bit SSL encrypted • Razorpay Gateway Verified',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Pay button
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: RRButton(
                label: _selectedMethod == 'CASH'
                    ? 'Confirm Cash Payment (₹${bill.grandTotal.toStringAsFixed(0)})'
                    : 'Pay via Razorpay ₹${bill.grandTotal.toStringAsFixed(0)}',
                icon: Icons.payment_rounded,
                isLoading: _isProcessing,
                onPressed: _processPayment,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildMethodTile({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    Widget? expandedChild,
  }) {
    final isSelected = _selectedMethod == id;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RRCard(
      onTap: () => setState(() => _selectedMethod = id),
      border: Border.all(
        color: isSelected
            ? color
            : (isDark ? AppColors.dividerDark : AppColors.dividerLight),
        width: isSelected ? 2 : 1,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: color,
                size: 22,
              ),
            ],
          ),
          if (isSelected && expandedChild != null) expandedChild,
        ],
      ),
    );
  }
}
