import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/admin_stats_model.dart';
import '../../../routes/app_routes.dart';
import '../../../services/admin_service.dart';
import '../../../services/api_client.dart';
import '../../../widgets/rr_button.dart';
import '../../../widgets/rr_card.dart';
import '../../../widgets/rr_status_badge.dart';
import '../../../widgets/app_logo.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  AdminStatsModel? _stats;
  List<dynamic> _providers = [];
  List<dynamic> _requests = [];
  List<dynamic> _payments = [];
  List<dynamic> _ratings = [];

  String _providerFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final statsFuture = AdminService.getStats();
      final provFuture = AdminService.listProviders(
        status: _providerFilter == 'ALL' ? null : _providerFilter,
      );
      final reqFuture = AdminService.listServiceRequests(limit: 25);
      final payFuture = AdminService.listPayments(limit: 25);
      final ratFuture = AdminService.listRatings(limit: 25);

      final results = await Future.wait([
        statsFuture,
        provFuture,
        reqFuture,
        payFuture,
        ratFuture,
      ]);

      if (mounted) {
        setState(() {
          _stats = results[0] as AdminStatsModel;
          _providers = (results[1] as Map<String, dynamic>)['providers'] as List<dynamic>? ?? [];
          _requests = (results[2] as Map<String, dynamic>)['requests'] as List<dynamic>? ?? [];
          _payments = (results[3] as Map<String, dynamic>)['payments'] as List<dynamic>? ?? [];
          _ratings = (results[4] as Map<String, dynamic>)['ratings'] as List<dynamic>? ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e is ApiException ? e.message : e.toString();
        });
      }
    }
  }

  Future<void> _handleVerificationAction(
    String providerUserId,
    String targetStatus, {
    String? reason,
  }) async {
    try {
      await AdminService.updateProviderVerification(
        providerUserId,
        verificationStatus: targetStatus,
        reason: reason,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Provider status changed to $targetStatus'),
            backgroundColor: targetStatus == 'APPROVED'
                ? AppColors.success
                : AppColors.danger,
          ),
        );
        _loadAllData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${e.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _showActionDialog(
    BuildContext context,
    String providerUserId,
    String providerName,
    String actionStatus,
  ) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$actionStatus Provider'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to mark $providerName as $actionStatus?'),
            if (actionStatus != 'APPROVED') ...[
              const SizedBox(height: 14),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reason (Optional)',
                  hintText: 'e.g. Incomplete documentation',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: actionStatus == 'APPROVED'
                  ? AppColors.success
                  : AppColors.danger,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _handleVerificationAction(
                providerUserId,
                actionStatus,
                reason: reasonCtrl.text.trim().isNotEmpty
                    ? reasonCtrl.text.trim()
                    : null,
              );
            },
            child: Text(actionStatus, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            AppLogo.appBar(
              height: 28,
            ),
            SizedBox(width: 10),
            Text(
              'Admin Portal',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh metrics',
            onPressed: _loadAllData,
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app_rounded),
            tooltip: 'Switch Portal',
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.roleSelect,
                (r) => false,
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_rounded, size: 18), text: 'Overview'),
            Tab(icon: Icon(Icons.verified_user_rounded, size: 18), text: 'Providers'),
            Tab(icon: Icon(Icons.car_crash_rounded, size: 18), text: 'Requests'),
            Tab(icon: Icon(Icons.payments_rounded, size: 18), text: 'Revenue'),
            Tab(icon: Icon(Icons.star_rounded, size: 18), text: 'Ratings'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: AppColors.danger, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'Error loading admin data:\n$_errorMessage',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        RRButton(
                          label: 'Retry',
                          icon: Icons.refresh_rounded,
                          onPressed: _loadAllData,
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(isDark),
                    _buildProvidersTab(isDark),
                    _buildRequestsTab(isDark),
                    _buildRevenueTab(isDark),
                    _buildRatingsTab(isDark),
                  ],
                ),
    );
  }

  // ── Tab 1: Overview ─────────────────────────────────────────────────────────
  Widget _buildOverviewTab(bool isDark) {
    final s = _stats;
    if (s == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Platform Status: Healthy',
                        style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'RoadRescue Command Center',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total Gross Revenue: ₹${s.totalRevenue.toStringAsFixed(2)}',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.analytics_rounded, color: AppColors.primary, size: 28),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Metric Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.35,
            children: [
              _buildMetricCard(
                'Active Requests',
                s.activeRequests.toString(),
                Icons.radar_rounded,
                AppColors.warning,
                isDark,
              ),
              _buildMetricCard(
                'Completed Jobs',
                s.completedRequests.toString(),
                Icons.task_alt_rounded,
                AppColors.success,
                isDark,
              ),
              _buildMetricCard(
                'Pending Approvals',
                s.pendingVerifications.toString(),
                Icons.pending_actions_rounded,
                AppColors.danger,
                isDark,
              ),
              _buildMetricCard(
                'Approved Providers',
                s.approvedProviders.toString(),
                Icons.verified_rounded,
                AppColors.primary,
                isDark,
              ),
              _buildMetricCard(
                'Total Customers',
                s.totalCustomers.toString(),
                Icons.people_alt_rounded,
                Colors.indigo,
                isDark,
              ),
              _buildMetricCard(
                'Avg Provider Rating',
                '⭐ ${s.averageRating.toStringAsFixed(1)}',
                Icons.star_rounded,
                AppColors.starRating,
                isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return RRCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Providers Verification ───────────────────────────────────────────
  Widget _buildProvidersTab(bool isDark) {
    return Column(
      children: [
        // Filter row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['ALL', 'PENDING', 'APPROVED', 'REJECTED', 'SUSPENDED']
                  .map((f) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(f),
                          selected: _providerFilter == f,
                          onSelected: (val) {
                            if (val) {
                              setState(() => _providerFilter = f);
                              _loadAllData();
                            }
                          },
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
        Expanded(
          child: _providers.isEmpty
              ? const Center(child: Text('No providers match this filter'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _providers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final p = _providers[i] as Map<String, dynamic>;
                    final profile = p['providerProfile'] as Map<String, dynamic>? ?? {};
                    final status = profile['verificationStatus'] as String? ?? 'PENDING';
                    final category = profile['category'] as String? ?? 'MECHANIC';
                    final garage = profile['garageName'] as String? ?? 'Independent Specialist';
                    final userId = p['id'] as String;
                    final name = p['name'] as String? ?? 'Provider';

                    return RRCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              RRStatusBadge(
                                label: status,
                                color: status == 'APPROVED'
                                    ? AppColors.success
                                    : status == 'PENDING'
                                        ? AppColors.warning
                                        : AppColors.danger,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$garage • $category',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '📞 ${p["mobile"] ?? ""} • ✉️ ${p["email"] ?? ""}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 12),
                          // Action Buttons
                          Row(
                            children: [
                              if (status != 'APPROVED')
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.success,
                                    ),
                                    onPressed: () => _showActionDialog(
                                      context,
                                      userId,
                                      name,
                                      'APPROVED',
                                    ),
                                    child: const Text('Approve', style: TextStyle(color: Colors.white)),
                                  ),
                                ),
                              if (status != 'APPROVED') const SizedBox(width: 8),
                              if (status == 'PENDING')
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.danger,
                                    ),
                                    onPressed: () => _showActionDialog(
                                      context,
                                      userId,
                                      name,
                                      'REJECTED',
                                    ),
                                    child: const Text('Reject'),
                                  ),
                                ),
                              if (status == 'APPROVED')
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.danger,
                                    ),
                                    onPressed: () => _showActionDialog(
                                      context,
                                      userId,
                                      name,
                                      'SUSPENDED',
                                    ),
                                    child: const Text('Suspend Provider'),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── Tab 3: Requests ─────────────────────────────────────────────────────────
  Widget _buildRequestsTab(bool isDark) {
    if (_requests.isEmpty) {
      return const Center(child: Text('No service requests found'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _requests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final r = _requests[i] as Map<String, dynamic>;
        final customer = r['customer'] as Map<String, dynamic>? ?? {};
        final provider = r['provider'] as Map<String, dynamic>? ?? {};
        final status = r['status'] as String? ?? 'PENDING';

        return RRCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    r['serviceType'] as String? ?? 'Roadside Request',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  RRStatusBadge(
                    label: status,
                    color: status == 'COMPLETED'
                        ? AppColors.success
                        : status == 'CANCELLED'
                            ? AppColors.danger
                            : AppColors.warning,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '🚗 ${r["vehicleModel"] ?? ""} (${r["vehiclePlate"] ?? ""})',
                style: const TextStyle(fontSize: 13),
              ),
              Text(
                '👤 Driver: ${customer["name"] ?? "Customer"} • 🔧 Specialist: ${provider["name"] ?? "Unassigned"}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
              ),
              if (r['problemDescription'] != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Issue: ${r["problemDescription"]}',
                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ── Tab 4: Revenue & Payments ───────────────────────────────────────────────
  Widget _buildRevenueTab(bool isDark) {
    if (_payments.isEmpty) {
      return const Center(child: Text('No payment records found'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _payments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final p = _payments[i] as Map<String, dynamic>;
        final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
        final method = p['method'] as String? ?? 'UPI';
        final txn = p['transactionId'] as String? ?? 'TXN-0000';
        final status = p['status'] as String? ?? 'COMPLETED';

        return RRCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '₹${amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Txn: $txn • $method',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                  ),
                ],
              ),
              RRStatusBadge(
                label: status,
                color: status == 'COMPLETED' ? AppColors.success : AppColors.danger,
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Tab 5: Ratings & Moderation ─────────────────────────────────────────────
  Widget _buildRatingsTab(bool isDark) {
    if (_ratings.isEmpty) {
      return const Center(child: Text('No ratings submitted yet'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _ratings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final r = _ratings[i] as Map<String, dynamic>;
        final score = (r['score'] as num?)?.toInt() ?? 5;
        final review = r['review'] as String? ?? 'No written comment provided.';
        final customer = r['customer'] as Map<String, dynamic>? ?? {};
        final provider = r['provider'] as Map<String, dynamic>? ?? {};
        final ratingId = r['id'] as String;

        return RRCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(
                      5,
                      (s) => Icon(
                        s < score ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: AppColors.starRating,
                        size: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                    tooltip: 'Moderate / Remove review',
                    onPressed: () async {
                      await AdminService.deleteRating(ratingId);
                      _loadAllData();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                review,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(
                'By ${customer["name"] ?? "Customer"} for ${provider["name"] ?? "Provider"}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        );
      },
    );
  }
}
