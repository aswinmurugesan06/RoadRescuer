import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/vehicle_model.dart';
import '../../../routes/app_routes.dart';
import '../../../services/ai_damage_service.dart';
import '../../../services/cost_estimation_service.dart';
import '../../../widgets/ai_damage_assessment_card.dart';
import '../../../widgets/glass.dart';

class CostEstimationScreen extends StatefulWidget {
  final VehicleModel? vehicle;
  final String? initialServiceType;

  const CostEstimationScreen({
    super.key,
    this.vehicle,
    this.initialServiceType,
  });

  @override
  State<CostEstimationScreen> createState() => _CostEstimationScreenState();
}

class _CostEstimationScreenState extends State<CostEstimationScreen> {
  late String _vehicleType;
  late String _issueCategory;
  double _distanceKm = 10;
  double _laborHours = 1;
  double _partsEstimate = 0;
  final _partsController = TextEditingController();
  AiDamageAssessment? _aiAssessment;

  @override
  void initState() {
    super.initState();
    _vehicleType = widget.vehicle?.type ?? 'Car';
    if (!CostEstimationService.vehicleMultipliers.containsKey(_vehicleType)) {
      _vehicleType = 'Car';
    }
    _issueCategory = widget.initialServiceType != null &&
            CostEstimationService.issueCategories.contains(widget.initialServiceType)
        ? widget.initialServiceType!
        : 'Mechanic';
  }

  @override
  void dispose() {
    _partsController.dispose();
    super.dispose();
  }

  CostEstimate get _estimate => CostEstimationService.estimate(
        vehicleType: _vehicleType,
        issueCategory: _issueCategory,
        distanceKm: _distanceKm,
        laborHours: _laborHours,
        partsEstimate: _partsEstimate,
      );

  void _applyAiAssessment(AiDamageAssessment assessment) {
    final result = assessment.result;
    final category = CostEstimationService.issueCategories
            .contains(result.mappedCategory)
        ? result.mappedCategory
        : 'Mechanic';

    setState(() {
      _aiAssessment = assessment;
      _issueCategory = category;
      _laborHours = result.estimatedLaborHours.clamp(0.0, 8.0).toDouble();
      _partsEstimate = result.estimatedPartsCost;
      _partsController.text =
          _partsEstimate <= 0 ? '' : _partsEstimate.toStringAsFixed(0);
    });
  }

  void _requestService() {
    final assessment = _aiAssessment;
    final adjustedAssessment = assessment?.copyWith(
      result: assessment.result.copyWith(
        estimatedLaborHours: _laborHours,
        estimatedPartsCost: _partsEstimate,
      ),
    );

    Navigator.pushNamed(
      context,
      AppRoutes.selectProblem,
      arguments: {
        'serviceType': _issueCategory,
        'vehicle': widget.vehicle,
        'estimatedAmount': _estimate.total,
        'aiAssessment': adjustedAssessment,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final estimate = _estimate;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: GlassBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isDark),
                const SizedBox(height: 16),
                AiDamageAssessmentCard(
                  key: ValueKey('ai-$_vehicleType'),
                  vehicleType: _vehicleType,
                  estimate: estimate,
                  onAssessment: _applyAiAssessment,
                ),
                const SizedBox(height: 14),
                _buildInputs(isDark),
                const SizedBox(height: 14),
                _buildEstimateCard(isDark, estimate),
                const SizedBox(height: 14),
                _buildBreakdown(isDark, estimate),
                const SizedBox(height: 18),
                GradientActionButton(
                  label: 'Request this service',
                  icon: Icons.arrow_forward_rounded,
                  colors: const [Color(0xFF0045D1), Color(0xFF1A5CFF)],
                  onPressed: _requestService,
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    'Final invoice may vary after on-site diagnosis. GST included.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.white,
              ),
            ),
            child: const Icon(Icons.arrow_back_rounded, size: 20),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dynamic Cost Estimator',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
              Text(
                'Estimate before you book',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
        const GlassIconBox(
          icon: Icons.calculate_rounded,
          size: 40,
          iconSize: 20,
        ),
      ],
    );
  }

  Widget _buildInputs(bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Vehicle type', isDark),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _vehicleType,
            isExpanded: true,
            decoration: _inputDecoration(),
            items: CostEstimationService.vehicleMultipliers.keys
                .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _vehicleType = value;
                  _aiAssessment = null;
                });
              }
            },
          ),
          const SizedBox(height: 12),
          _label('Issue category', isDark),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _issueCategory,
            isExpanded: true,
            decoration: _inputDecoration(),
            items: CostEstimationService.issueCategories
                .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _issueCategory = value);
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _label('Distance to breakdown', isDark)),
              Text(
                '${_distanceKm.toStringAsFixed(1)} km',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          Slider(
            value: _distanceKm,
            min: 0,
            max: 50,
            divisions: 50,
            activeColor: AppColors.primary,
            label: '${_distanceKm.toStringAsFixed(0)} km',
            onChanged: (value) => setState(() => _distanceKm = value),
          ),
          Row(
            children: [
              Expanded(child: _label('Labor hours', isDark)),
              Text(
                '${_laborHours.toStringAsFixed(1)} h',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          Slider(
            value: _laborHours,
            min: 0,
            max: 8,
            divisions: 16,
            activeColor: AppColors.primary,
            label: '${_laborHours.toStringAsFixed(1)} h',
            onChanged: (value) => setState(() => _laborHours = value),
          ),
          const SizedBox(height: 4),
          _label('Parts estimate (optional)', isDark),
          const SizedBox(height: 6),
          TextFormField(
            controller: _partsController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: _inputDecoration(
              hint: 'e.g. 850',
              prefix: '₹ ',
            ),
            onChanged: (value) {
              setState(() {
                _partsEstimate = double.tryParse(value) ?? 0;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEstimateCard(bool isDark, CostEstimate estimate) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0045D1), Color(0xFF1A5CFF)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.28),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: const Text(
                    'ESTIMATED RANGE',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.verified_user_rounded,
                  size: 16, color: Colors.white70),
              const SizedBox(width: 4),
              const Flexible(
                child: Text(
                  'Transparent pricing',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9, color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '₹${estimate.lowRange.toStringAsFixed(0)} – ₹${estimate.highRange.toStringAsFixed(0)}',
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Most likely ₹${estimate.total.toStringAsFixed(0)} including GST',
            style: const TextStyle(fontSize: 10, color: Colors.white70),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _estimatePill('$_issueCategory', Icons.build_rounded),
              _estimatePill(_vehicleType, Icons.directions_car_rounded),
              _estimatePill('${_distanceKm.toStringAsFixed(0)} km',
                  Icons.route_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _estimatePill(String label, IconData icon) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdown(bool isDark, CostEstimate estimate) {
    return GlassCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Estimate breakdown',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                'GST 18%',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _row('Emergency callout', estimate.baseCallout),
          _row('${estimate.issueCategory} service base', estimate.categoryBase),
          _row(
            'Distance (${estimate.distanceKm.toStringAsFixed(1)} km)',
            estimate.distanceCharge,
          ),
          _row('Labor (${estimate.laborHours.toStringAsFixed(1)} h)', estimate.laborCharge),
          if (estimate.partsEstimate > 0)
            _row('Parts estimate', estimate.partsEstimate),
          _row('Vehicle multiplier', null, suffix: '×${estimate.vehicleMultiplier}'),
          Divider(
            color: isDark ? Colors.white12 : AppColors.dividerLight,
            height: 18,
          ),
          _row('Subtotal', estimate.subtotal),
          _row('GST 18%', estimate.taxAmount),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Estimated total',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '₹${estimate.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, double? amount, {String? suffix}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
          Text(
            suffix ?? '₹${(amount ?? 0).toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint, String? prefix}) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefix,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      fillColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withOpacity(0.06)
          : Colors.white.withOpacity(0.75),
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white12
              : AppColors.borderLight,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white12
              : AppColors.borderLight,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}
