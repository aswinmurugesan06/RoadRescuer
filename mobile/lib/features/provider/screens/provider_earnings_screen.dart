import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/provider_service.dart';
import '../../../widgets/rr_card.dart';
import '../../../widgets/rr_loading.dart';
import '../../../widgets/rr_status_badge.dart';

class ProviderEarningsScreen extends StatefulWidget {
  const ProviderEarningsScreen({super.key});

  @override
  State<ProviderEarningsScreen> createState() => _ProviderEarningsScreenState();
}

class _ProviderEarningsScreenState extends State<ProviderEarningsScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _earnings;

  @override
  void initState() {
    super.initState();
    _loadEarnings();
  }

  Future<void> _loadEarnings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ProviderService.getEarnings();
      if (mounted) {
        setState(() {
          _earnings = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Unable to load earnings data. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(dynamic dateVal) {
    if (dateVal == null) return 'Recently';
    final dt = DateTime.tryParse(dateVal.toString())?.toLocal();
    if (dt == null) return dateVal.toString();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Earnings & Settlements'),
          automaticallyImplyLeading: false,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Earnings & Settlements'),
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadEarnings,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final grossBilling = (_earnings?['grossServiceBilling'] as num?)?.toDouble() ?? 0.0;
    final totalCompletedServices = (_earnings?['totalCompletedServices'] as num?)?.toInt() ?? 0;
    final platformCommission = (_earnings?['platformCommission'] as num?)?.toDouble() ?? 0.0;
    final netEarnings = (_earnings?['netProviderEarnings'] as num?)?.toDouble() ?? 0.0;
    final recentPayments = (_earnings?['recentPayments'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Earnings & Settlements'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Earnings',
            onPressed: _loadEarnings,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadEarnings,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Earnings hero card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF064E3B), Color(0xFF047857)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOTAL BALANCE (PENDING PAYOUT)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Color(0xFFA7F3D0),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹${netEarnings.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.account_balance_wallet_rounded,
                              size: 14, color: Color(0xFFA7F3D0)),
                          const SizedBox(width: 6),
                          Text(
                            recentPayments.isNotEmpty
                                ? '${recentPayments.length} completed ${recentPayments.length == 1 ? 'service payment' : 'service payments'} on record'
                                : 'No completed service payments yet',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFFE2E8F0)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Real stats overview
                const SectionHeader(title: 'Earnings Breakdown'),
                const SizedBox(height: 12),
                RRCard(
                  child: Column(
                    children: [
                      InfoRow(
                        label: 'Total Completed Services',
                        value: '$totalCompletedServices ${totalCompletedServices == 1 ? 'Job' : 'Jobs'}',
                      ),
                      const Divider(),
                      InfoRow(
                        label: 'Gross Service Billing',
                        value: '₹${grossBilling.toStringAsFixed(2)}',
                      ),
                      const Divider(),
                      InfoRow(
                        label: 'Platform Commission (10%)',
                        value: '- ₹${platformCommission.toStringAsFixed(2)}',
                      ),
                      const Divider(),
                      InfoRow(
                        label: 'Net Provider Earnings',
                        value: '₹${netEarnings.toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Payout & Payment history
                SectionHeader(
                  title: recentPayments.isNotEmpty
                      ? 'Recent Completed Settlements (${recentPayments.length})'
                      : 'Recent Bank Settlements',
                ),
                const SizedBox(height: 12),
                if (recentPayments.isEmpty)
                  const RREmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'No Completed Settlements Yet',
                    subtitle: 'Completed roadside service payments will appear here in real-time.',
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recentPayments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final p = recentPayments[i];
                      final displayId = (p['receiptNumber'] ?? p['transactionId'] ?? 'SETTLEMENT').toString();
                      final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
                      final netAmount = (p['netAmount'] as num?)?.toDouble() ?? amount;
                      final dateStr = _formatDate(p['paidAt'] ?? p['createdAt']);
                      final customerName = p['customerName'] ?? 'Customer';
                      final serviceType = p['serviceType'] ?? 'Service';

                      return RRCard(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.account_balance_rounded,
                                color: AppColors.success,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayId,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$serviceType • $customerName',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                  Text(
                                    dateStr,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${netAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Gross: ₹${amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const RRStatusBadge(
                                  label: 'PAID',
                                  color: AppColors.success,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
