import 'dart:async';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/mapbox_gl.dart';
import '../../../routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/service_request_model.dart';
import '../../../models/bill_model.dart';
import '../../../services/service_request_service.dart';
import '../../../services/billing_service.dart';
import '../../../services/socket_service.dart';
import '../../../services/routing_service.dart';
import '../../../widgets/rr_button.dart';
import '../../../widgets/rr_card.dart';
import '../../../widgets/rr_map_view.dart';
import '../../../widgets/rr_status_badge.dart';

class ActiveAssistanceScreen extends StatefulWidget {
  final ServiceRequestModel? request;

  const ActiveAssistanceScreen({super.key, this.request});

  @override
  State<ActiveAssistanceScreen> createState() => _ActiveAssistanceScreenState();
}

class _ActiveAssistanceScreenState extends State<ActiveAssistanceScreen> {
  ServiceRequestModel? _request;
  BillModel? _bill;
  Timer? _pollingTimer;
  bool _isRefreshing = false;
  bool _isCancelling = false;

  // Live provider location & Route (Socket.IO & RoutingService)
  double? _providerLat;
  double? _providerLng;
  List<LatLng> _routeCoordinates = [];
  double? _routeDistanceKm;
  int? _routeDurationMinutes;
  bool _isCalculatingRoute = false;

  final List<String> _stepTitles = [
    'Request Accepted',
    'Provider En Route',
    'Arrived at Breakdown Spot',
    'Repair In Progress',
    'Service Completed',
  ];

  @override
  void initState() {
    super.initState();
    _request = widget.request;
    _connectSocket();
    _startPolling();
    _fetchBill();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    final reqId = _request?.id;
    if (reqId != null && reqId.isNotEmpty) {
      SocketService.instance.leaveRequestRoom(reqId);
    }
    super.dispose();
  }

  // ── Socket.IO ─────────────────────────────────────────────────────────
  Future<void> _connectSocket() async {
    final reqId = _request?.id;
    if (reqId == null || reqId.isEmpty) return;

    await SocketService.instance.connect();
    SocketService.instance.joinRequestRoom(reqId);

    // Live provider GPS location
    SocketService.instance.onProviderLocation = (id, lat, lng) {
      if (id == reqId && mounted) {
        setState(() {
          _providerLat = lat;
          _providerLng = lng;
        });
        _updateCustomerRoute(lat, lng);
      }
    };

    // Status change from server (real-time, replaces polling hit)
    SocketService.instance.onStatusChange = (id, status) {
      if (id == reqId && mounted) {
        _handleStatusChange(status);
        _fetchBill();
      }
    };

    // Provider accepted (shows provider info immediately)
    SocketService.instance.onRequestAccepted = (data) {
      if (data['requestId'] == reqId && mounted) {
        _refreshRequestStatus();
      }
    };

    // Cancellation pushed from server
    SocketService.instance.onRequestCancelled = (id, reason) {
      if (id == reqId && mounted) {
        _refreshRequestStatus();
      }
    };

    // Bill created or updated
    SocketService.instance.onBillCreated = (data) {
      if (data['requestId'] == reqId && mounted) {
        _fetchBill();
        _refreshRequestStatus();
      }
    };

    // Bill status update
    SocketService.instance.onBillStatus = (data) {
      if (data['requestId'] == reqId && mounted) {
        _fetchBill();
      }
    };

    // Payment success
    SocketService.instance.onPaymentSuccess = (data) {
      if (data['requestId'] == reqId && mounted) {
        _fetchBill();
        _refreshRequestStatus();
      }
    };
  }

  void _handleStatusChange(String rawStatus) {
    final req = _request;
    if (req == null) return;
    // Map the raw string from the server to the existing enum
    final updated = req.copyWith(
      status: ServiceRequestModel.fromJson({'status': rawStatus}).status,
    );
    if (mounted) setState(() => _request = updated);
  }

  void _startPolling() {
    if (_request == null) return;
    // 8s polling as fallback when socket is unavailable
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_request?.status != RequestStatus.completed &&
          _request?.status != RequestStatus.cancelled) {
        _refreshRequestStatus();
      }
    });
  }

  Future<void> _fetchBill() async {
    final reqId = _request?.id ?? widget.request?.id;
    if (reqId == null || reqId.isEmpty) return;

    try {
      final bill = await BillingService.getBillByRequestId(reqId);
      if (mounted) {
        setState(() {
          _bill = bill;
        });
      }
    } catch (_) {
      // Backend polling error ignored silently
    }
  }

  Future<void> _refreshRequestStatus() async {
    final req = _request;
    if (req == null || req.id.isEmpty) return;

    try {
      final updated = await ServiceRequestService.getRequestById(req.id);
      if (mounted) {
        setState(() {
          _request = updated;
        });
      }
    } catch (_) {
      // Backend polling error ignored silently
    }
    await _fetchBill();
  }

  int get _currentStepIndex {
    if (_bill != null && _bill!.status == 'PAID') return 4;
    final status = _request?.status;
    if (status == null) return 1;
    switch (status) {
      case RequestStatus.pending:
      case RequestStatus.searching:
        return 0;
      case RequestStatus.accepted:
        return 0;
      case RequestStatus.arriving:
        return 1;
      case RequestStatus.inService:
      case RequestStatus.active:
        return 3;
      case RequestStatus.completed:
        return 4;
      case RequestStatus.cancelled:
        return 0;
    }
  }

  Future<void> _confirmCancel() async {
    final req = _request;
    if (req == null) return;

    final reasonController = TextEditingController(text: 'Changed my mind / alternate help arrived');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Request?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to cancel your roadside assistance request?',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for cancellation',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Request'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Request'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isCancelling = true);
      try {
        final cancelled = await ServiceRequestService.cancelRequest(
          req.id,
          reason: reasonController.text.trim(),
        );
        if (mounted) {
          setState(() {
            _request = cancelled;
            _isCancelling = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your assistance request was cancelled.'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isCancelling = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to cancel: ${e.toString()}'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final req = _request;
    final status = req?.status ?? RequestStatus.accepted;
    final isSearching = status == RequestStatus.pending || status == RequestStatus.searching;
    final isCancelled = status == RequestStatus.cancelled;
    final isCompleted = status == RequestStatus.completed || (_bill != null && _bill!.status == 'PAID');
    final hasPendingInvoice = _bill != null && (_bill!.status == 'PENDING' || _bill!.status == 'APPROVED');

    return Scaffold(
      appBar: AppBar(
        title: Text(isSearching
            ? 'Searching for Provider'
            : (isCancelled
                ? 'Request Cancelled'
                : (hasPendingInvoice
                    ? 'Payment Required'
                    : (isCompleted ? 'Assistance Completed' : 'Live Assistance Status')))),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Status',
            onPressed: () async {
              setState(() => _isRefreshing = true);
              await _refreshRequestStatus();
              if (mounted) setState(() => _isRefreshing = false);
            },
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Banner ──────────────────────────────────
              if (isSearching)
                _buildSearchingBanner()
              else if (isCancelled)
                _buildCancelledBanner()
              else if (isCompleted && !hasPendingInvoice)
                _buildCompletedBanner()
              else
                _buildActiveBanner(),

              const SizedBox(height: 24),

              // ── Body Content by State ──────────────────────────
              if (isSearching) ...[
                // Searching State Cards
                _buildSearchingDetailsCard(isDark),
                const SizedBox(height: 24),
                _buildCancelSection(),
              ] else if (isCancelled) ...[
                // Cancelled State
                _buildCancelledDetailsCard(isDark),
                const SizedBox(height: 24),
                RRButton(
                  label: 'Return to Customer Dashboard',
                  icon: Icons.home_rounded,
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.customer,
                      (r) => false,
                    );
                  },
                ),
              ] else ...[
                // Assigned / Active State
                _buildProviderContactCard(isDark),
                const SizedBox(height: 24),

                // ── Real Backend Invoice / Payment Section ──────────
                if (hasPendingInvoice) ...[
                  _buildInvoiceCard(isDark),
                  const SizedBox(height: 24),
                ] else if (_bill != null && _bill!.status == 'PAID') ...[
                  _buildPaidInvoiceCard(isDark),
                  const SizedBox(height: 24),
                ],

                if (!isCompleted && !hasPendingInvoice) ...[
                  _buildPinCard(),
                  const SizedBox(height: 28),
                ],

                _buildStepperTrack(),

                // ── Live Provider Location Map ──────────────────────
                if (_providerLat != null && _providerLng != null) ...[
                  const SizedBox(height: 24),
                  _buildProviderLiveMapCard(),
                ],
                const SizedBox(height: 28),

                if (!isCompleted &&
                    !hasPendingInvoice &&
                    (status == RequestStatus.accepted ||
                        status == RequestStatus.arriving))
                  _buildCancelSection(),

                if (isCompleted || (_bill != null && _bill!.status == 'PAID')) ...[
                  RRButton(
                    label: 'Rate & Review Provider',
                    icon: Icons.star_rounded,
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.rating,
                      arguments: {
                        'request': _request,
                        'requestId': _request?.id,
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  RRButton(
                    label: 'View Receipt & Summary',
                    icon: Icons.receipt_long_rounded,
                    variant: RRButtonVariant.secondary,
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.receipt,
                      arguments: {'requestId': _request?.id},
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Invoice Ready / Payment Required Card ───────────────────────────
  Widget _buildInvoiceCard(bool isDark) {
    final bill = _bill;
    if (bill == null) return const SizedBox.shrink();

    final isApproved = bill.status == 'APPROVED';
    final statusColor = isApproved ? AppColors.info : AppColors.warning;
    final statusLabel = isApproved ? 'APPROVED' : 'PAYMENT REQUIRED';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Invoice Ready',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '#INV-${bill.requestId.length >= 8 ? bill.requestId.substring(0, 8).toUpperCase() : bill.requestId.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 10),

          // Items breakdown list
          for (int i = 0; i < bill.items.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${bill.items[i].description} (${bill.items[i].quantity}x)',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '₹${bill.items[i].total.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),

          InfoRow(label: 'Subtotal', value: '₹${bill.subtotal.toStringAsFixed(2)}'),
          InfoRow(label: 'GST / Tax (18%)', value: '₹${bill.taxAmount.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Payable',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              Text(
                '₹${bill.grandTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),

          if (bill.notes != null && bill.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppColors.info),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bill.notes!,
                      style: const TextStyle(fontSize: 12, color: AppColors.info),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),

          // Actions
          RRButton(
            label: 'Approve & Pay ₹${bill.grandTotal.toStringAsFixed(0)}',
            icon: Icons.payment_rounded,
            onPressed: () async {
              await Navigator.pushNamed(
                context,
                AppRoutes.payment,
                arguments: {'bill': bill},
              );
              _fetchBill();
              _refreshRequestStatus();
            },
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () async {
                await Navigator.pushNamed(
                  context,
                  AppRoutes.bill,
                  arguments: {'requestId': _request?.id},
                );
                _fetchBill();
                _refreshRequestStatus();
              },
              icon: const Icon(Icons.receipt_long_outlined, size: 16),
              label: const Text(
                'View Itemized Breakdown & Dispute Options',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Paid Invoice Card ───────────────────────────────────────────────
  Widget _buildPaidInvoiceCard(bool isDark) {
    final bill = _bill;
    if (bill == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.success.withOpacity(0.45),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Completed',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '₹${bill.grandTotal.toStringAsFixed(2)} Paid in Full',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.receipt,
                  arguments: {'requestId': bill.requestId},
                ),
                icon: const Icon(Icons.receipt_rounded, size: 16),
                label: const Text('Receipt'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.success,
                  side: const BorderSide(color: AppColors.success),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Active Banner ──────────────────────────────────────────────────
  Widget _buildActiveBanner() {
    final stepIndex = _currentStepIndex;
    final stepTitle = stepIndex < _stepTitles.length ? _stepTitles[stepIndex] : 'In Progress';
    final hasPendingInvoice = _bill != null && (_bill!.status == 'PENDING' || _bill!.status == 'APPROVED');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (hasPendingInvoice ? AppColors.warning : AppColors.primary).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      hasPendingInvoice ? Icons.receipt_long_rounded : Icons.fiber_manual_record,
                      color: hasPendingInvoice ? AppColors.warning : AppColors.primary,
                      size: hasPendingInvoice ? 13 : 10,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      hasPendingInvoice ? 'INVOICE READY' : 'LIVE ASSISTANCE',
                      style: TextStyle(
                        color: hasPendingInvoice ? AppColors.warning : AppColors.primaryLight,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                hasPendingInvoice
                    ? 'Payment Due'
                    : (stepIndex >= 2 ? 'On Site' : 'En Route'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            hasPendingInvoice ? 'Invoice Ready for Payment' : stepTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasPendingInvoice
                ? 'Total amount of ₹${_bill!.grandTotal.toStringAsFixed(2)} submitted by ${_bill!.providerName}.'
                : (_request != null
                    ? '${_request!.serviceType} — ${_request!.location}'
                    : 'Service in progress'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  // ── Searching State Banner ─────────────────────────────────────────
  Widget _buildSearchingBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A1B0E), Color(0xFF422810)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.radar_rounded, color: AppColors.warning, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'LOOKING FOR PROVIDER',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'Estimated 2–5 min',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Broadcasting Request',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Contacting verified ${_request?.serviceType ?? "roadside"} providers near your GPS breakdown spot.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
          ),
        ],
      ),
    );
  }

  // ── Cancelled Banner ───────────────────────────────────────────────
  Widget _buildCancelledBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.danger.withOpacity(0.35)),
      ),
      child: Column(
        children: [
          const Icon(Icons.cancel_outlined, color: AppColors.danger, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Request Cancelled',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _request?.cancellationReason ?? 'This request was cancelled.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
          ),
        ],
      ),
    );
  }

  // ── Completed Banner ───────────────────────────────────────────────
  Widget _buildCompletedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.success.withOpacity(0.35)),
      ),
      child: Column(
        children: const [
          Icon(Icons.check_circle_rounded, color: AppColors.success, size: 48),
          SizedBox(height: 12),
          Text(
            'Service Completed!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.success,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Your breakdown has been serviced by the provider.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
          ),
        ],
      ),
    );
  }

  // ── Searching Details Card ─────────────────────────────────────────
  Widget _buildSearchingDetailsCard(bool isDark) {
    final req = _request;

    return RRCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Looking for matching mechanics...',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              RRStatusBadge(
                label: req?.category ?? 'PENDING',
                color: AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          InfoRow(label: 'Service', value: req?.serviceType ?? 'Mechanic'),
          const Divider(),
          InfoRow(label: 'Issue', value: req?.problem ?? 'Breakdown'),
          const Divider(),
          InfoRow(
            label: 'Vehicle',
            value: '${req?.vehicleModel ?? "Vehicle"} (${req?.vehiclePlate ?? ""})',
          ),
          const Divider(),
          InfoRow(label: 'Location', value: req?.location ?? 'GPS Spot'),
        ],
      ),
    );
  }

  // ── Cancelled Details Card ─────────────────────────────────────────
  Widget _buildCancelledDetailsCard(bool isDark) {
    return RRCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cancellation Details',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          InfoRow(
            label: 'Reason',
            value: _request?.cancellationReason ?? 'Cancelled by customer',
          ),
          const Divider(),
          InfoRow(label: 'Service', value: _request?.serviceType ?? 'Mechanic'),
          const Divider(),
          InfoRow(
            label: 'Vehicle',
            value: '${_request?.vehicleModel ?? ""} (${_request?.vehiclePlate ?? ""})',
          ),
        ],
      ),
    );
  }

  // ── Provider Contact Card ──────────────────────────────────────────
  Widget _buildProviderContactCard(bool isDark) {
    final providerName = _request?.providerName ?? 'Assigned Mechanic';
    final providerMobile = _request?.providerMobile ?? '+91 99887 76655';

    return RRCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.person_pin_rounded, color: AppColors.secondary, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      providerName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_request?.category ?? "Service"} Specialist • Verified Provider',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Calling $providerMobile...')),
                    );
                  },
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: const Text('Call Provider'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Connecting to specialist direct channel...')),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: const Text('Message'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── PIN Card ───────────────────────────────────────────────────────
  Widget _buildPinCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.pin_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Service Start PIN',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 2),
                Text(
                  'Share PIN with provider when they arrive',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.servicePin),
            child: const Text('View PIN', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Stepper Track ──────────────────────────────────────────────────
  Widget _buildStepperTrack() {
    final currentStep = _currentStepIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Assistance Progress'),
        const SizedBox(height: 16),
        for (int i = 0; i < _stepTitles.length; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i <= currentStep ? AppColors.primary : Colors.grey.withOpacity(0.3),
                    ),
                    child: Icon(
                      i < currentStep ? Icons.check : Icons.circle,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                  if (i < _stepTitles.length - 1)
                    Container(
                      width: 2,
                      height: 36,
                      color: i < currentStep ? AppColors.primary : Colors.grey.withOpacity(0.3),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _stepTitles[i],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: i == currentStep ? FontWeight.w800 : FontWeight.w500,
                        color: i <= currentStep ? null : Colors.grey,
                      ),
                    ),
                    if (i == currentStep) ...[
                      const SizedBox(height: 2),
                      const Text(
                        'In progress right now',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ── Cancel Section ─────────────────────────────────────────────────
  Widget _buildCancelSection() {
    return Center(
      child: TextButton.icon(
        onPressed: _isCancelling ? null : _confirmCancel,
        icon: _isCancelling
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.danger),
              )
            : const Icon(Icons.cancel_outlined, color: AppColors.danger, size: 18),
        label: const Text(
          'Cancel Assistance Request',
          style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Future<void> _updateCustomerRoute(double provLat, double provLng) async {
    final custLat = _request?.customerLatitude;
    final custLng = _request?.customerLongitude;
    if (custLat == null || custLng == null || _isCalculatingRoute) return;

    _isCalculatingRoute = true;
    try {
      final route = await RoutingService.getDirections(
        originLat: provLat,
        originLng: provLng,
        destLat: custLat,
        destLng: custLng,
      );
      if (mounted) {
        setState(() {
          _routeCoordinates = route.coordinates;
          _routeDistanceKm = route.distanceKm;
          _routeDurationMinutes = route.durationMinutes;
          _isCalculatingRoute = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isCalculatingRoute = false);
    }
  }

  // ── Provider Live Location Map Card ────────────────────────────────
  Widget _buildProviderLiveMapCard() {
    final provLat = _providerLat!;
    final provLng = _providerLng!;
    final custLat = _request?.customerLatitude;
    final custLng = _request?.customerLongitude;

    final distanceLabel = _routeDistanceKm != null ? '${_routeDistanceKm!.toStringAsFixed(1)} km' : null;
    final etaLabel = _routeDurationMinutes != null ? '$_routeDurationMinutes min ETA' : null;

    // Center the map on the provider's current location with route
    return RRCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.location_on_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Provider Live Location & Route',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      distanceLabel != null && etaLabel != null
                          ? '$distanceLabel away • $etaLabel'
                          : 'Live GPS navigation tracking',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondaryLight),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.circle, color: AppColors.success, size: 8),
                    SizedBox(width: 4),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 220,
              child: RRMapView(
                initialLatitude: provLat,
                initialLongitude: provLng,
                routeCoordinates: _routeCoordinates,
                routeColor: AppColors.primary,
                routeWidth: 4.5,
                initialZoom: 14.5,
                showUserLocation: false,
                additionalMarkers: [
                  // Provider marker
                  RRMapMarker(
                    id: 'provider',
                    latitude: provLat,
                    longitude: provLng,
                    label: 'Technician',
                    color: AppColors.primary,
                  ),
                  // Customer location marker (if available)
                  if (custLat != null && custLng != null)
                    RRMapMarker(
                      id: 'customer',
                      latitude: custLat,
                      longitude: custLng,
                      label: 'Your Breakdown Spot',
                      color: AppColors.danger,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Live GPS Fix: ${provLat.toStringAsFixed(5)}, ${provLng.toStringAsFixed(5)}',
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondaryLight),
          ),
        ],
      ),
    );
  }
}
