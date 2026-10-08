import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/mock_data.dart';
import '../../../models/service_request_model.dart';
import '../../../routes/app_routes.dart';
import '../../../services/service_request_service.dart';
import '../../../services/billing_service.dart';
import '../../../widgets/request_card_widget.dart';
import '../../../widgets/rr_loading.dart';

class RequestHistoryScreen extends StatefulWidget {
  const RequestHistoryScreen({super.key});

  @override
  State<RequestHistoryScreen> createState() => _RequestHistoryScreenState();
}

class _RequestHistoryScreenState extends State<RequestHistoryScreen> {
  List<ServiceRequestModel> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final realReqs = await ServiceRequestService.getMyRequests();
      if (mounted) {
        setState(() {
          _requests = realReqs.isNotEmpty ? realReqs : MockData.recentRequests;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _requests = MockData.recentRequests;
          _isLoading = false;
        });
      }
    }
  }

  void _onSelectRequest(ServiceRequestModel r) {
    if (r.status != RequestStatus.completed && r.status != RequestStatus.cancelled) {
      Navigator.pushNamed(
        context,
        AppRoutes.activeAssistance,
        arguments: {'request': r},
      ).then((_) => _loadRequests());
    } else if (r.status == RequestStatus.completed) {
      Navigator.pushNamed(context, AppRoutes.bill);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Requests'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadRequests,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? const RREmptyState(
                  icon: Icons.receipt_long_rounded,
                  title: 'No Requests Yet',
                  subtitle: 'Your roadside assistance requests will appear here.',
                )
              : RefreshIndicator(
                  onRefresh: _loadRequests,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _requests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => RequestCardWidget(
                      request: _requests[i],
                      onTap: () => _onSelectRequest(_requests[i]),
                    ),
                  ),
                ),
    );
  }
}

// ── Customer Payment History ─────────────────────────────────────────
class CustomerPaymentHistoryScreen extends StatefulWidget {
  const CustomerPaymentHistoryScreen({super.key});

  @override
  State<CustomerPaymentHistoryScreen> createState() =>
      _CustomerPaymentHistoryScreenState();
}

class _CustomerPaymentHistoryScreenState
    extends State<CustomerPaymentHistoryScreen> {
  List<PaymentHistoryItem> _payments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoading = true);
    try {
      final realPayments = await BillingService.getMyPayments();
      if (mounted) {
        setState(() {
          _payments = realPayments;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _payments = [];
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    final year = dt.year;
    return '$day $month $year';
  }

  IconData _getServiceIcon(String category, String service) {
    final cat = category.toUpperCase();
    final s = service.toLowerCase();
    if (cat == 'PUNCTURE' || s.contains('puncture') || s.contains('tyre')) {
      return Icons.tire_repair_rounded;
    }
    if (cat == 'TOW_TRUCK' || s.contains('tow') || s.contains('recovery')) {
      return Icons.local_shipping_rounded;
    }
    if (cat == 'BATTERY' || s.contains('battery') || s.contains('jump')) {
      return Icons.battery_charging_full_rounded;
    }
    if (cat == 'FUEL' || s.contains('fuel') || s.contains('petrol') || s.contains('diesel')) {
      return Icons.local_gas_station_rounded;
    }
    return Icons.build_rounded;
  }

  Color _getServiceColor(String category, String service) {
    final cat = category.toUpperCase();
    final s = service.toLowerCase();
    if (cat == 'PUNCTURE' || s.contains('puncture') || s.contains('tyre')) {
      return AppColors.puncture;
    }
    if (cat == 'TOW_TRUCK' || s.contains('tow') || s.contains('recovery')) {
      return AppColors.tow;
    }
    if (cat == 'BATTERY' || s.contains('battery') || s.contains('jump')) {
      return AppColors.battery;
    }
    if (cat == 'FUEL' || s.contains('fuel') || s.contains('petrol') || s.contains('diesel')) {
      return AppColors.fuel;
    }
    return AppColors.mechanic;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadPayments,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _payments.isEmpty
              ? RefreshIndicator(
                  onRefresh: _loadPayments,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 100),
                      RREmptyState(
                        icon: Icons.payment_rounded,
                        title: 'No Payments Yet',
                        subtitle:
                            'Your completed service payment history will appear here.',
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPayments,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _payments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final p = _payments[i];
                      final serviceIcon = _getServiceIcon(p.category, p.service);
                      final serviceColor = _getServiceColor(p.category, p.service);

                      return InkWell(
                        onTap: () {
                          if (p.requestId.isNotEmpty) {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.receipt,
                              arguments: {
                                'paymentId': p.paymentId,
                                'requestId': p.requestId,
                              },
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.cardDark : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.dividerDark
                                  : AppColors.dividerLight,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: serviceColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  serviceIcon,
                                  color: serviceColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.service,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      p.provider,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatDate(p.paidAt),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₹${p.amount.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.successSurface,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      p.status,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
