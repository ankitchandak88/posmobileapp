import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../auth/state/auth_providers.dart';
import '../../../dashboard/state/dashboard_providers.dart';
import '../../state/scanner_providers.dart';

/// Dedicated read-only Quick Item View screen. Allows warehouse/retail
/// staff to inspect product details, active batches, expiry dates, and shelf
/// locations without initiating an unwanted stock-count observation.
class QuickItemViewScreen extends ConsumerWidget {
  const QuickItemViewScreen({super.key, required this.item, this.taskId});

  final ItemModel item;
  final String? taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final branches = ref.watch(branchesProvider).value;
    final selectedBranchId = ref.watch(selectedBranchIdProvider);
    final branchId =
        selectedBranchId ??
        auth.user?.branchId ??
        (branches != null && branches.isNotEmpty ? branches.first.id : '1');

    final batchesAsync = ref.watch(
      itemBatchesProvider((itemId: item.id, branchId: branchId)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Details'),
        backgroundColor: AppColors.navy,
        actions: [
          IconButton(
            tooltip: 'Scan Another Barcode',
            icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
            onPressed: () => context.push(
              '/scanner',
              extra: {'mode': 'view', 'taskId': taskId},
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Primary Product Header Card
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.infoBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.info.withValues(alpha: 0.18),
                          ),
                        ),
                        child: const Icon(
                          Icons.inventory_2_rounded,
                          color: AppColors.info,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: AppTextStyles.bodyStrong.copyWith(fontSize: 15),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text('Item ID: #${item.id}', style: AppTextStyles.caption.copyWith(fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SKU Code', style: AppTextStyles.caption),
                            const SizedBox(height: 2),
                            Text(
                              item.sku.isNotEmpty ? item.sku : '-',
                              style: AppTextStyles.barcode,
                            ),
                          ],
                        ),
                      ),
                      if (item.barcode != null && item.barcode!.isNotEmpty)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Barcode / EAN', style: AppTextStyles.caption),
                              const SizedBox(height: 2),
                              Text(item.barcode!, style: AppTextStyles.barcode),
                            ],
                          ),
                        ),
                      if (item.mrp != null)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('MRP', style: AppTextStyles.caption),
                              const SizedBox(height: 2),
                              Text(
                                '₹${item.mrp}',
                                style: AppTextStyles.bodyStrong.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // 2. Batches & Expiry Information
            Text('Batches & Expiry Dates', style: AppTextStyles.h3),
            const SizedBox(height: AppSpacing.sm),
            batchesAsync.when(
              data: (batches) {
                if (batches.isEmpty) {
                  return AppCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'No active batches found for this branch.',
                            style: AppTextStyles.caption,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: batches.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final b = batches[index];
                    return AppCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.layers_outlined,
                                      size: 16,
                                      color: AppColors.navy,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Batch: ${b.batchNo}',
                                      style: AppTextStyles.bodyStrong,
                                    ),
                                  ],
                                ),
                                if (b.expDate != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Exp: ${b.expDate!.day}/${b.expDate!.month}/${b.expDate!.year}',
                                    style: AppTextStyles.caption,
                                  ),
                                ],
                                if (b.rackSection != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Rack: ${b.rackSection}',
                                    style: AppTextStyles.captionMuted,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (b.expDate != null)
                            _ExpiryBadge(expDate: b.expDate!),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const ShimmerListPlaceholder(itemCount: 2),
              error: (e, _) => ErrorState(message: e.toString()),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // 3. Quick Actions
            Text('Actions for this Product', style: AppTextStyles.h3),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Start Stock Count',
              icon: Icons.inventory_2_outlined,
              onPressed: () {
                context.push(
                  '/stock-count',
                  extra: {'item': item, 'batch': null, 'taskId': taskId},
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Verify Expiry Date',
              variant: AppButtonVariant.secondary,
              icon: Icons.event_available_outlined,
              onPressed: () {
                context.push(
                  '/expiry-check',
                  extra: {'item': item, 'batch': null, 'taskId': taskId},
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpiryBadge extends StatelessWidget {
  const _ExpiryBadge({required this.expDate});
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
