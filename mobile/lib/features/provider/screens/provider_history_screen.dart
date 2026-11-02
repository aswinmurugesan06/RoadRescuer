import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/service_request_model.dart';
import '../../../services/provider_service.dart';
import '../../../widgets/request_card_widget.dart';
import '../../../widgets/rr_button.dart';
import '../../../widgets/rr_card.dart';
import '../../../widgets/rr_loading.dart';
import '../../../widgets/rr_status_badge.dart';

class ProviderHistoryScreen extends StatefulWidget {
  const ProviderHistoryScreen({super.key});

  @override
  State<ProviderHistoryScreen> createState() => _ProviderHistoryScreenState();
}

class _ProviderHistoryScreenState extends State<ProviderHistoryScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<ServiceRequestModel> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final jobs = await ProviderService.getJobHistory();
      if (mounted) {
        setState(() {
          _history = jobs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('ApiException: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _showJobDetails(BuildContext context, ServiceRequestModel job) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedDate =
        '${job.date.day.toString().padLeft(2, '0')}/${job.date.month.toString().padLeft(2, '0')}/${job.date.year} at ${job.date.hour.toString().padLeft(2, '0')}:${job.date.minute.toString().padLeft(2, '0')}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Job #${job.id.length >= 8 ? job.id.substring(0, 8).toUpperCase() : job.id.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const RRStatusBadge(
                    label: 'COMPLETED',
                    color: AppColors.success,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              // Details
              InfoRow(label: 'Service Category', value: job.category ?? job.serviceType),
              const Divider(),
              InfoRow(label: 'Service Type', value: job.serviceType),
              const Divider(),
              InfoRow(
                label: 'Vehicle',
                value: '${job.vehicleModel.isNotEmpty ? job.vehicleModel : "Vehicle"} (${job.vehiclePlate.isNotEmpty ? job.vehiclePlate : "N/A"})',
              ),
              const Divider(),
              InfoRow(label: 'Issue Reported', value: job.problem),
              const Divider(),
              InfoRow(label: 'Location', value: job.location),
              const Divider(),
              InfoRow(label: 'Completed On', value: formattedDate),
              const Divider(),
              if (job.customerName != null && job.customerName!.isNotEmpty) ...[
                InfoRow(
                  label: 'Customer',
                  value: job.customerMobile != null
                      ? '${job.customerName} (${job.customerMobile})'
                      : job.customerName!,
                ),
                const Divider(),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Amount Paid',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    job.totalAmount > 0
                        ? '₹${job.totalAmount.toStringAsFixed(2)}'
                        : 'Free / Included',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              RRButton(
                label: 'Close',
                variant: RRButtonVariant.secondary,
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job History'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh History',
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: RRLoading(message: 'Loading job history...'),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 52, color: AppColors.danger),
              const SizedBox(height: 16),
              const Text(
                'Failed to load job history',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
              ),
              const SizedBox(height: 20),
              RRButton(
                label: 'Retry',
                icon: Icons.refresh_rounded,
                onPressed: _loadHistory,
              ),
            ],
          ),
        ),
      );
    }

    if (_history.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadHistory,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 100),
            RREmptyState(
              icon: Icons.history_rounded,
              title: 'No Completed Jobs Yet',
              subtitle: 'Your completed and paid assistance services will appear here.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: _history.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final job = _history[i];
          return RequestCardWidget(
            request: job,
            onTap: () => _showJobDetails(context, job),
          );
        },
      ),
    );
  }
}
