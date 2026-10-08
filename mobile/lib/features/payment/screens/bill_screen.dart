import 'package:flutter/material.dart';
import '../../../routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/bill_model.dart';
import '../../../services/billing_service.dart';
import '../../../widgets/rr_button.dart';
import '../../../widgets/rr_card.dart';

class BillScreen extends StatefulWidget {
  /// Service request ID to fetch the bill for.
  final String? requestId;

  const BillScreen({super.key, this.requestId});

  @override
  State<BillScreen> createState() => _BillScreenState();
}

class _BillScreenState extends State<BillScreen> {
  BillModel? _bill;
  bool _isLoading = true;
  String? _error;
  bool _isApproving = false;
  bool _isRejecting = false;

  @override
  void initState() {
    super.initState();
    _loadBill();
  }

  Future<void> _loadBill() async {
    final reqId = widget.requestId;
    if (reqId == null || reqId.isEmpty) {
      // Fallback to mock for design preview
      setState(() {
        _bill = BillModel.mock;
        _isLoading = false;
      });
      return;
    }

    try {
      final bill = await BillingService.getBillByRequestId(reqId);
      if (mounted) {
        setState(() {
          _bill = bill ?? BillModel.mock;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load bill. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _approveBill() async {
    final bill = _bill;
    if (bill == null || bill.id.isEmpty || bill.id == 'mock-bill-001') return;

    setState(() => _isApproving = true);
    try {
      final updated = await BillingService.approveBill(bill.id);
      if (mounted) setState(() => _bill = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not approve: ${e.toString().split('):').last.trim()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isApproving = false);
    }
  }

  Future<void> _rejectBill() async {
    final bill = _bill;
    if (bill == null || bill.id.isEmpty || bill.id == 'mock-bill-001') return;

    final reasonCtrl = TextEditingController();

    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Bill?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please explain why you are disputing this invoice:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Rejection reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              if (reasonCtrl.text.trim().isNotEmpty) {
                Navigator.pop(ctx, reasonCtrl.text.trim());
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != null && mounted) {
      setState(() => _isRejecting = true);
      try {
        final updated = await BillingService.rejectBill(bill.id, confirmed);
        if (mounted) setState(() => _bill = updated);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not reject: ${e.toString().split('):').last.trim()}'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isRejecting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Invoice & Bill Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Invoice & Bill Details')),
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
                    _loadBill();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final bill = _bill!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPaid = bill.status == 'PAID';
    final isRejected = bill.status == 'REJECTED';
    final isApproved = bill.status == 'APPROVED';
    final isPending = bill.status == 'PENDING';

    Color statusColor;
    String statusLabel;
    if (isPaid) {
      statusColor = AppColors.success;
      statusLabel = 'PAID';
    } else if (isRejected) {
      statusColor = AppColors.danger;
      statusLabel = 'DISPUTED';
    } else if (isApproved) {
      statusColor = AppColors.info;
      statusLabel = 'APPROVED';
    } else {
      statusColor = AppColors.warning;
      statusLabel = 'PENDING';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice & Bill Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() => _isLoading = true);
              _loadBill();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Provider header
                    RRCard(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.receipt_long_rounded,
                              color: AppColors.primary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bill.providerName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Invoice #INV-${bill.requestId.length > 8 ? bill.requestId.substring(0, 8).toUpperCase() : bill.requestId.toUpperCase()}',
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Itemized bill table
                    const SectionHeader(title: 'Service & Parts Breakdown'),
                    const SizedBox(height: 12),
                    RRCard(
                      child: Column(
                        children: [
                          for (int i = 0; i < bill.items.length; i++) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          bill.items[i].description,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          'Qty: ${bill.items[i].quantity} × ₹${bill.items[i].unitPrice.toStringAsFixed(0)}',
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
                                  Text(
                                    '₹${bill.items[i].total.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (i < bill.items.length - 1) const Divider(),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Calculations summary
                    RRCard(
                      child: Column(
                        children: [
                          InfoRow(
                            label: 'Subtotal',
                            value: '₹${bill.subtotal.toStringAsFixed(2)}',
                          ),
                          const Divider(),
                          InfoRow(
                            label: 'GST / Tax (18%)',
                            value: '₹${bill.taxAmount.toStringAsFixed(2)}',
                          ),
                          const Divider(),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Payable',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '₹${bill.grandTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Rejection reason
                    if (isRejected && bill.rejectionReason != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.danger.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 18, color: AppColors.danger),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Disputed: ${bill.rejectionReason}',
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

                    // Notes
                    if (bill.notes != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.info.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.info.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline,
                                size: 18, color: AppColors.info),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Note from Technician: ${bill.notes}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.info,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Approve / Reject row (only when PENDING)
                    if (isPending) ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isRejecting ? null : _rejectBill,
                              icon: _isRejecting
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.thumb_down_outlined,
                                      size: 16),
                              label: const Text('Dispute'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.danger,
                                side: const BorderSide(
                                    color: AppColors.danger),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isApproving ? null : _approveBill,
                              icon: _isApproving
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.thumb_up_outlined,
                                      size: 16),
                              label: const Text('Approve'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.success,
                                side: const BorderSide(
                                    color: AppColors.success),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Dispute text button for completed state
                    if (!isPaid)
                      Center(
                        child: TextButton.icon(
                          onPressed: () =>
                              Navigator.pushNamed(context, AppRoutes.complaint),
                          icon: const Icon(Icons.report_problem_outlined,
                              size: 16),
                          label: const Text('Raise a Formal Complaint'),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Bottom Pay Action
            if (!isPaid && !isRejected)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: RRButton(
                  label:
                      'Proceed to Pay ₹${bill.grandTotal.toStringAsFixed(0)}',
                  icon: Icons.lock_outline_rounded,
                  onPressed: isPaid
                      ? null
                      : () => Navigator.pushNamed(
                            context,
                            AppRoutes.payment,
                            arguments: {'bill': bill},
                          ),
                ),
              ),

            if (isPaid)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: RRButton(
                  label: 'View Receipt',
                  icon: Icons.receipt_rounded,
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoutes.receipt,
                    arguments: {'requestId': bill.requestId},
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
