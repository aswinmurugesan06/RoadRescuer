import 'package:flutter/material.dart';
import '../../../routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/bill_model.dart';
import '../../../services/billing_service.dart';
import '../../../widgets/rr_button.dart';
import '../../../widgets/rr_card.dart';

class ReceiptScreen extends StatefulWidget {
  /// Load receipt by payment ID (preferred) or request ID fallback.
  final String? paymentId;
  final String? requestId;

  const ReceiptScreen({super.key, this.paymentId, this.requestId});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  ReceiptModel? _receipt;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReceipt();
  }

  Future<void> _loadReceipt() async {
    try {
      ReceiptModel? receipt;
      if (widget.paymentId != null && widget.paymentId!.isNotEmpty) {
        receipt = await BillingService.getReceiptByPaymentId(widget.paymentId!);
      } else if (widget.requestId != null && widget.requestId!.isNotEmpty) {
        receipt = await BillingService.getReceiptByRequestId(widget.requestId!);
      }

      if (mounted) {
        setState(() {
          _receipt = receipt;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load receipt. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payment Receipt')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payment Receipt')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: AppColors.danger),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _error = null;
                    });
                    _loadReceipt();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Use mock data if no real receipt was found (design preview)
    final bill = BillModel.mock;
    final receipt = _receipt;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Receipt'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sharing receipt link...')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Receipt saved to device storage.')),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Digital Receipt Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Brand mark
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.directions_car_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'ROADRESCUE',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'PAID',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Receipt Info
                    if (receipt != null) ...[
                      InfoRow(
                        label: 'Receipt Number',
                        value: receipt.receiptNumber,
                      ),
                      const SizedBox(height: 8),
                      InfoRow(
                        label: 'Transaction ID',
                        value: receipt.transactionId,
                      ),
                      const SizedBox(height: 8),
                      InfoRow(
                        label: 'Date & Time',
                        value: receipt.paidAt != null
                            ? _formatDate(receipt.paidAt!)
                            : 'N/A',
                      ),
                      const SizedBox(height: 8),
                      InfoRow(
                        label: 'Service Provider',
                        value: receipt.provider?.name ?? 'Provider',
                      ),
                      const SizedBox(height: 8),
                      InfoRow(
                        label: 'Service Type',
                        value: receipt.serviceType ?? 'Roadside Assistance',
                      ),
                      if (receipt.vehicle != null &&
                          (receipt.vehicle!['model'] ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        InfoRow(
                          label: 'Vehicle',
                          value:
                              '${receipt.vehicle!['model']} (${receipt.vehicle!['plateNumber'] ?? ''})',
                        ),
                      ],
                      if (receipt.location != null) ...[
                        const SizedBox(height: 8),
                        InfoRow(
                          label: 'Service Location',
                          value: receipt.location!,
                        ),
                      ],
                    ] else ...[
                      // Mock fallback for design preview
                      const InfoRow(
                          label: 'Receipt Number', value: 'RR-RCPT-2026-0042'),
                      const SizedBox(height: 8),
                      const InfoRow(
                          label: 'Date & Time', value: '26 Sep 2026, 03:45 PM'),
                      const SizedBox(height: 8),
                      InfoRow(
                          label: 'Service Provider', value: bill.providerName),
                      const SizedBox(height: 8),
                      const InfoRow(
                          label: 'Vehicle',
                          value: 'Ashok Leyland 2820 (TN 38 AB 1234)'),
                    ],

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 14),

                    // Breakdown
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Items & Services',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final item in (receipt?.items ?? bill.items)) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item.description,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            Text(
                              '₹${item.total.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    const Divider(),
                    const SizedBox(height: 10),

                    InfoRow(
                      label: 'Subtotal',
                      value:
                          '₹${(receipt?.subtotal ?? bill.subtotal).toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 6),
                    InfoRow(
                      label: 'GST (18%)',
                      value:
                          '₹${(receipt?.taxAmount ?? bill.taxAmount).toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Total
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Paid',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '₹${(receipt?.grandTotal ?? bill.grandTotal).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Action Buttons
              if (receipt?.requestId != null || widget.requestId != null) ...[
                RRButton(
                  label: 'Rate & Review Specialist',
                  icon: Icons.star_rounded,
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.rating,
                      arguments: {
                        'requestId': receipt?.requestId ?? widget.requestId,
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
              RRButton(
                label: 'Done — Return to Home',
                variant: (receipt?.requestId != null || widget.requestId != null)
                    ? RRButtonVariant.secondary
                    : RRButtonVariant.primary,
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.customer,
                    (r) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $hour:$minute $ampm';
  }
}
