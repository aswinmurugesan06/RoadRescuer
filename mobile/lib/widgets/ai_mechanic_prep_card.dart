import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/service_request_model.dart';

/// Provider-facing "Mechanic Prep" card built from the AI damage report.
///
/// Renders nothing when the request has no AI assessment, so older requests
/// keep their existing layout.
class AiMechanicPrepCard extends StatelessWidget {
  final ServiceRequestModel request;

  const AiMechanicPrepCard({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    if (!request.hasAiDamageReport) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tools = request.requiredTools;
    final parts = request.recommendedParts;
    final indicators = request.visibleIndicators;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mechanic Prep — AI Damage Report',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? Colors.white
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    const Text(
                      'Bring the right tools and parts on the first visit.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              if ((request.aiSeverity ?? '').isNotEmpty) ...[
                const SizedBox(width: 8),
                _severityBadge(request.aiSeverity!),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if ((request.damageImageUrl ?? '').isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                request.damageImageUrl!,
                width: double.infinity,
                height: 155,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _imagePlaceholder(),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return _imagePlaceholder(loading: true);
                },
              ),
            )
          else
            _imagePlaceholder(),
          const SizedBox(height: 11),
          if ((request.aiDetectedIssue ?? '').isNotEmpty)
            Text(
              request.aiDetectedIssue!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
          if ((request.aiDetectedIssue ?? '').isNotEmpty) const SizedBox(height: 6),
          if (indicators.isNotEmpty) ...[
            _chipWrap(
              indicators,
              color: AppColors.danger,
              icon: Icons.visibility_rounded,
            ),
            const SizedBox(height: 12),
          ],
          if (tools.isNotEmpty) ...[
            _sectionLabel('Required tools to bring'),
            const SizedBox(height: 6),
            _chipWrap(
              tools,
              color: AppColors.primary,
              icon: Icons.handyman_rounded,
            ),
            const SizedBox(height: 12),
          ],
          if (parts.isNotEmpty) ...[
            _sectionLabel('Recommended spare parts'),
            const SizedBox(height: 6),
            _chipWrap(
              parts,
              color: AppColors.tertiary,
              icon: Icons.settings_suggest_rounded,
            ),
            const SizedBox(height: 12),
          ],
          if (request.estimatedLaborHours != null ||
              request.estimatedPartsCost != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Est. labour ${(request.estimatedLaborHours ?? 1).toStringAsFixed(2)}h'
                      ' • Est. parts '
                      '₹${(request.estimatedPartsCost ?? 0).toStringAsFixed(0)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if ((request.mechanicPrepNote ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.tips_and_updates_rounded,
                    size: 15,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      request.mechanicPrepNote!,
                      style: const TextStyle(
                        fontSize: 9.5,
                        height: 1.35,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _imagePlaceholder({bool loading = false}) {
    return Container(
      width: double.infinity,
      height: 155,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.image_search_rounded,
                    size: 26,
                    color: AppColors.primary,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Damage photo not available',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 8,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: AppColors.textSecondaryLight,
      ),
    );
  }

  Widget _severityBadge(String severity) {
    final color = switch (severity) {
      'Severe' => AppColors.danger,
      'Low' => AppColors.success,
      _ => AppColors.warning,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        severity.toUpperCase(),
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          color: color,
        ),
      ),
    );
  }

  Widget _chipWrap(
    List<String> items, {
    required Color color,
    required IconData icon,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: items.map((item) {
            return ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.15)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 11, color: color),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 9,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
