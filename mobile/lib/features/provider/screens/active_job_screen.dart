import 'package:flutter/material.dart';
import '../../../routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/service_request_model.dart';
import '../../../services/service_request_service.dart';
import '../../../services/phone_service.dart';
import '../../../services/provider_service.dart';
import '../../../widgets/ai_mechanic_prep_card.dart';
import '../../../widgets/rr_button.dart';
import '../../../widgets/rr_card.dart';
import '../../../widgets/rr_status_badge.dart';

class ActiveJobScreen extends StatefulWidget {
  final ServiceRequestModel? request;

  const ActiveJobScreen({super.key, this.request});

  @override
  State<ActiveJobScreen> createState() => _ActiveJobScreenState();
}

class _ActiveJobScreenState extends State<ActiveJobScreen> {
  ServiceRequestModel? _request;

  final List<Map<String, dynamic>> _tasks = [
    {'title': 'Vehicle on-site diagnostics & assessment', 'done': true},
    {'title': 'Inspect reported problem & components', 'done': true},
    {'title': 'Execute roadside repair / recovery procedure', 'done': true},
    {'title': 'Test vehicle operation & system checks', 'done': false},
    {'title': 'Final inspection & customer confirmation', 'done': false},
  ];

  @override
  void initState() {
    super.initState();
    _request = widget.request;
    _fetchFullRequestDetails();
  }

  Future<void> _fetchFullRequestDetails() async {
    final reqId = _request?.id ?? widget.request?.id;
    if (reqId != null && reqId.isNotEmpty) {
      try {
        final fullReq = await ServiceRequestService.getRequestById(reqId);
        if (mounted) {
          setState(() {
            _request = fullReq;
          });
        }
      } catch (_) {}
    } else {
      // Look for current active request assigned to this provider
      try {
        final myReqs = await ProviderService.getMyRequests();
        if (myReqs.isNotEmpty) {
          final activeJson = myReqs.firstWhere(
            (r) => ['IN_SERVICE', 'ARRIVING', 'ACCEPTED']
                .contains((r['status'] as String? ?? '').toUpperCase()),
            orElse: () => myReqs.first,
          );
          if (mounted) {
            setState(() {
              _request = ServiceRequestModel.fromJson(activeJson);
            });
          }
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final req = _request ?? widget.request;
    final jobId = req != null && req.id.isNotEmpty
        ? (req.id.length >= 8 ? req.id.substring(0, 8).toUpperCase() : req.id.toUpperCase())
        : 'ACTIVE';
    final vehicleModel = req?.vehicleModel.isNotEmpty == true
        ? req!.vehicleModel
        : 'Assistance Vehicle';
    final vehicleType = req?.vehicleType?.isNotEmpty == true ? ' (${req!.vehicleType})' : '';
    final vehiclePlate = req?.vehiclePlate.isNotEmpty == true
        ? req!.vehiclePlate
        : 'Not Specified';
    final customerName = req?.customerName?.isNotEmpty == true
        ? req!.customerName!
        : (req?.customerMobile != null ? 'Customer (${req!.customerMobile})' : 'Customer');
    final customerMobile = req?.customerMobile;
    final problem = req?.problem.isNotEmpty == true
        ? req!.problem
        : 'Emergency Roadside Assistance';
    final locationText = req?.location.isNotEmpty == true
        ? req!.location
        : 'Breakdown Location';

    return Scaffold(
      appBar: AppBar(
        title: Text('Active Job #$jobId'),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_rounded, color: AppColors.primary),
            onPressed: () async {
              final opened = await PhoneService.call(customerMobile);
              if (!opened && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Could not open the phone dialer.'),
                  ),
                );
              }
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
                    // Job Status Hero Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              RRStatusBadge(
                                label: req != null ? req.status.label.toUpperCase() : 'REPAIR IN PROGRESS',
                                color: AppColors.warning,
                              ),
                              const Text(
                                'Active Job',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '$vehicleModel$vehicleType',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Plate: $vehiclePlate • Customer: $customerName',
                            style: const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.place_rounded, size: 16, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  locationText,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFFE2E8F0)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Reported Problem
                    const SectionHeader(title: 'Reported Issue'),
                    const SizedBox(height: 10),
                    RRCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            problem,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Service provider assigned and fulfilling request for $customerName.',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (req != null && req.hasAiDamageReport) ...[
                      AiMechanicPrepCard(request: req),
                      const SizedBox(height: 24),
                    ],

                    // Repair Checklist
                    const SectionHeader(title: 'Work Checklist'),
                    const SizedBox(height: 10),
                    RRCard(
                      child: Column(
                        children: [
                          for (int i = 0; i < _tasks.length; i++) ...[
                            CheckboxListTile(
                              value: _tasks[i]['done'] as bool,
                              activeColor: AppColors.primary,
                              title: Text(
                                _tasks[i]['title'] as String,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  decoration: (_tasks[i]['done'] as bool)
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) {
                                setState(() => _tasks[i]['done'] = val ?? false);
                              },
                            ),
                            if (i < _tasks.length - 1) const Divider(),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              AppRoutes.providerNavigation,
                              arguments: {'request': req},
                            ),
                            icon: const Icon(Icons.navigation_outlined, size: 16),
                            label: const Text('View Location'),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              AppRoutes.providerServicePin,
                              arguments: {'request': req},
                            ),
                            icon: const Icon(Icons.pin_rounded, size: 16),
                            label: const Text('Re-check PIN'),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bottom CTA: Complete repair & bill
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
                label: 'Finish Repair & Generate Bill',
                icon: Icons.receipt_long_rounded,
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.createBill,
                    arguments: {'request': req},
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
