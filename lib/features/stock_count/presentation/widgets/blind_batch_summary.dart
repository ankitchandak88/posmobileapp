import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/models/models.dart';

/// Renders batch/expiry context on the blind stock-count screen.
///
/// DEFENSE IN DEPTH: this widget intentionally has NO code path that reads
/// or displays [BatchModel.systemQty] / [BatchModel.hasSystemQty] — even if
/// constructed with a [BatchModel] where those fields are populated (e.g. a
/// Manager/Owner batch response), nothing here renders them. The blind
/// stock-count UI must never have a slot for system quantity. A widget test
/// (test/widgets/blind_batch_summary_test.dart) asserts this.
class BlindBatchSummary extends StatelessWidget {
  const BlindBatchSummary({super.key, required this.batch});

  final BatchModel? batch;

  @override
  Widget build(BuildContext context) {
    if (batch == null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Text(
          'No batch selected — counting at item level.',
          style: AppTextStyles.caption,
        ),
      );
    }
    final b = batch!;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.inventory_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text('Batch: ${b.batchNo}', style: AppTextStyles.bodyStrong),
            ],
          ),
          if (b.expDate != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.event_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Expiry: ${b.expDate!.day}/${b.expDate!.month}/${b.expDate!.year}',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(width: AppSpacing.sm),
                _ExpiryCountdownBadge(expDate: b.expDate!),
              ],
            ),
          ],
          if (b.rackSection != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.shelves,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(b.rackSection!, style: AppTextStyles.caption),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ExpiryCountdownBadge extends StatelessWidget {
  const _ExpiryCountdownBadge({required this.expDate});
  final DateTime expDate;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(expDate.year, expDate.month, expDate.day);
    final days = target.difference(today).inDays;

    final Color bgColor;
    final Color textColor;
    final String label;

    if (days < 0) {
      bgColor = AppColors.criticalBg;
      textColor = AppColors.critical;
      label = 'Expired';
    } else if (days <= 30) {
      bgColor = AppColors.criticalBg;
      textColor = AppColors.critical;
      label = '$days d left';
    } else if (days <= 90) {
      bgColor = AppColors.warningBg;
      textColor = AppColors.warning;
      label = '$days d left';
    } else {
      bgColor = AppColors.successBg;
      textColor = AppColors.success;
      label = 'Fresh';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(
          color: textColor.withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

