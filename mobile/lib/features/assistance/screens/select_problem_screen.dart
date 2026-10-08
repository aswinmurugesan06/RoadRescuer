import 'package:flutter/material.dart';
import '../../../routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/mock_data.dart';
import '../../../models/vehicle_model.dart';
import '../../../widgets/rr_button.dart';
import '../../../widgets/rr_card.dart';
import '../../../widgets/rr_text_field.dart';

class SelectProblemScreen extends StatefulWidget {
  final String serviceType;
  final VehicleModel? vehicle;

  const SelectProblemScreen({
    super.key,
    required this.serviceType,
    this.vehicle,
  });

  @override
  State<SelectProblemScreen> createState() => _SelectProblemScreenState();
}

class _SelectProblemScreenState extends State<SelectProblemScreen> {
  late List<String> _problems;
  String? _selectedProblem;
  final _customDescController = TextEditingController();
  String _urgency = 'Moderate'; // Critical, Moderate, Low

  @override
  void initState() {
    super.initState();
    _problems = MockData.problemsByService[widget.serviceType] ?? [
      'General Breakdown',
      'Vehicle Won\'t Start',
      'Unusual Noise',
      'Other Problem',
    ];
    _selectedProblem = _problems.first;
  }

  @override
  void dispose() {
    _customDescController.dispose();
    super.dispose();
  }

  String get _finalProblemDescription {
    if (_customDescController.text.trim().isNotEmpty) {
      return '$_selectedProblem (${_customDescController.text.trim()})';
    }
    return _selectedProblem ?? 'Assistance Required';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.serviceType} Details'),
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
                    // Header prompt
                    Text(
                      'What seems to be the issue?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Select the specific problem to help providers bring right equipment.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Problem options list
                    RRCard(
                      child: Column(
                        children: _problems.map((prob) {
                          final isSelected = _selectedProblem == prob;
                          return InkWell(
                            onTap: () => setState(() => _selectedProblem = prob),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withOpacity(0.08)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: isSelected
                                        ? AppColors.primary
                                        : (isDark ? Colors.white30 : Colors.black26),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      prob,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        color: isSelected
                                            ? AppColors.primary
                                            : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Additional details
                    const SectionHeader(title: 'Additional Details (Optional)'),
                    const SizedBox(height: 10),
                    RRTextField(
                      label: 'Describe what happened',
                      hint: 'e.g. Smoke coming from radiator, loud squeaking, stuck on highway lane 2...',
                      controller: _customDescController,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),

                    // Urgency Level
                    const SectionHeader(title: 'Situation Urgency'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildUrgencyChip('Critical', 'Blocking traffic / Highway', AppColors.danger),
                        const SizedBox(width: 10),
                        _buildUrgencyChip('Moderate', 'On shoulder / Highway bay', AppColors.warning),
                        const SizedBox(width: 10),
                        _buildUrgencyChip('Low', 'Parked safely / Yard', AppColors.success),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bottom CTA
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
                label: 'Confirm Location',
                icon: Icons.location_on_rounded,
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.locationConfirm,
                    arguments: {
                      'serviceType': widget.serviceType,
                      'problem': _finalProblemDescription,
                      'vehicle': widget.vehicle,
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrgencyChip(String label, String sub, Color color) {
    final isSelected = _urgency == label;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _urgency = label),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.12) : (isDark ? AppColors.cardDark : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : (isDark ? AppColors.dividerDark : AppColors.dividerLight),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? color : null,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
