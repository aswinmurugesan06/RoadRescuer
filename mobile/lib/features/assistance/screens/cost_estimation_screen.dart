import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/vehicle_model.dart';
import '../../../routes/app_routes.dart';
import '../../../services/ai_damage_service.dart';
import '../../../services/cost_estimation_service.dart';
import '../../../widgets/ai_damage_assessment_card.dart';
import '../../../widgets/cost_breakdown_card.dart';
import '../../../widgets/glass.dart';

class CostEstimationScreen extends StatefulWidget {
  final VehicleModel? vehicle;
  final String? initialServiceType;
  final bool isProvider;

  const CostEstimationScreen({
    super.key,
    this.vehicle,
    this.initialServiceType,
    this.isProvider = false,
  });

  @override
  State<CostEstimationScreen> createState() => _CostEstimationScreenState();
}

class _CostEstimationScreenState extends State<CostEstimationScreen> {
  late String _vehicleType;
  late String _issueCategory;
  double _distanceKm = CostEstimationService.defaultDistanceKm;
  double _laborHours = 1.5;
  double _partsEstimate = 0;
  final _partsController = TextEditingController();
  AiDamageAssessment? _aiAssessment;
  int _aiVersion = 0;

  bool get _isProvider => widget.isProvider;

  double get _effectiveLaborHours {
    if (_isProvider) return _laborHours;
    final ai = _aiAssessment;
    if (ai != null) return ai.result.estimatedLaborHours.clamp(0.0, 8.0);
    return CostEstimationService.autoLaborHours(
      _issueCategory,
      severity: ai?.result.severity,
    );
  }

  double get _effectivePartsEstimate {
    if (_isProvider) return _partsEstimate;
    return _aiAssessment?.result.estimatedPartsCost ?? 0;
  }

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
    _laborHours = CostEstimationService.autoLaborHours(_issueCategory);
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
        laborHours: _effectiveLaborHours,
        partsEstimate: _effectivePartsEstimate,
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

  void _clearAiAssessment() {
    _aiAssessment = null;
    _aiVersion++;
  }

  void _requestService() {
    final assessment = _aiAssessment;
    final adjustedAssessment = assessment?.copyWith(
      result: assessment.result.copyWith(
        estimatedLaborHours: _effectiveLaborHours,
        estimatedPartsCost: _effectivePartsEstimate,
      ),
    );

    final estimate = _estimate;
    Navigator.pushNamed(
      context,
      AppRoutes.selectProblem,
      arguments: {
        'serviceType': _issueCategory,
        'vehicle': widget.vehicle,
        'estimatedAmount': estimate.total,
        'costEstimate': estimate,
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
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              MediaQuery.of(context).viewInsets.bottom + 28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isDark),
                const SizedBox(height: 16),
                AiDamageAssessmentCard(
                  key: ValueKey('ai-$_vehicleType-$_aiVersion'),
                  vehicleType: _vehicleType,
                  selectedCategory: _issueCategory,
                  estimate: estimate,
                  onAssessment: _applyAiAssessment,
                ),
                const SizedBox(height: 14),
                _buildInputs(isDark),
                const SizedBox(height: 14),
                _buildEstimateCard(isDark, estimate),
                const SizedBox(height: 14),
                CostBreakdownCard(
                  estimate: estimate,
                  isProvider: _isProvider,
                ),
                const SizedBox(height: 18),
                GradientActionButton(
                  label: _isProvider ? 'Done' : 'Request this service',
                  icon: _isProvider
                      ? Icons.check_rounded
                      : Icons.arrow_forward_rounded,
                  colors: const [Color(0xFF0045D1), Color(0xFF1A5CFF)],
                  onPressed: _isProvider
                      ? () => Navigator.pop(context)
                      : _requestService,
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
              color: isDark ? Colors.white10 : Colors.white.withValues(alpha: 0.8),
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
                _isProvider
                    ? 'Provider pricing tool — labour and parts adjustable'
                    : 'Auto-calculated before you book',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
            key: ValueKey('vehicle-$_vehicleType'),
            initialValue: _vehicleType,
            isExpanded: true,
            decoration: _inputDecoration(),
            items: CostEstimationService.vehicleMultipliers.keys
                .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _vehicleType = value;
                  _clearAiAssessment();
                });
              }
            },
          ),
          const SizedBox(height: 12),
          _label('Issue category', isDark),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            key: ValueKey('category-$_issueCategory'),
            initialValue: _issueCategory,
            isExpanded: true,
            decoration: _inputDecoration(),
            items: CostEstimationService.issueCategories
                .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _issueCategory = value;
                  _clearAiAssessment();
                  _laborHours =
                      CostEstimationService.autoLaborHours(value);
                  _partsEstimate = 0;
                  _partsController.clear();
                });
              }
            },
          ),
          const SizedBox(height: 14),
          if (_isProvider) ...[
            Row(
              children: [
                Expanded(child: _label('Distance to breakdown', isDark)),
                const SizedBox(width: 8),
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
                Expanded(child: _label('Labour hours (provider)', isDark)),
                const SizedBox(width: 8),
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
            _label('Parts estimate (provider)', isDark),
            const SizedBox(height: 6),
            TextFormField(
              controller: _partsController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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
          ] else ...[
            _readOnlyRow(
              'Travel distance (auto)',
              '${_distanceKm.toStringAsFixed(1)} km • '
                  '₹${_estimate.distanceCharge.toStringAsFixed(0)}',
              isDark,
            ),
            _readOnlyRow(
              'Auto-allocated labour',
              '${_effectiveLaborHours.toStringAsFixed(2)}h • '
                  '₹${_estimate.laborCharge.toStringAsFixed(0)}',
              isDark,
            ),
            _readOnlyRow(
              'Estimated spare parts',
              '₹${_effectivePartsEstimate.toStringAsFixed(0)}',
              isDark,
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Labour and travel are calculated automatically. The provider '
                'can adjust final labour and parts after on-site inspection.',
                style: TextStyle(
                  fontSize: 9,
                  height: 1.35,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _readOnlyRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
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
            color: AppColors.primary.withValues(alpha: 0.28),
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
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.2)),
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
              _estimatePill(_issueCategory, Icons.build_rounded),
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
        color: Colors.white.withValues(alpha: 0.13),
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
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.white.withValues(alpha: 0.75),
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
