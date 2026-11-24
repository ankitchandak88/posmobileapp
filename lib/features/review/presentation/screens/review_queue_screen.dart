import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../state/review_providers.dart';

/// Manager pending-review queue. Allowed to show variance (physical vs
/// system qty) since the reviewer role differs from blind-counting staff.
class ReviewQueueScreen extends ConsumerStatefulWidget {
  const ReviewQueueScreen({super.key});

  @override
  ConsumerState<ReviewQueueScreen> createState() => _ReviewQueueScreenState();
}

class _ReviewQueueScreenState extends ConsumerState<ReviewQueueScreen> {
  String _selectedType = 'all'; // 'all', 'stock_count', 'expiry_check'

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(pendingReviewProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Approval Queue')),
      body: Column(
        children: [
          // Filter Tabs (Stock Count, Expiry Check, All)
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All Submissions',
                    selected: _selectedType == 'all',
                    onTap: () => setState(() => _selectedType = 'all'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Stock Count',
                    icon: Icons.inventory_2_rounded,
                    selected: _selectedType == 'stock_count',
                    onTap: () => setState(() => _selectedType = 'stock_count'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Expiry Verification',
                    icon: Icons.event_busy_rounded,
                    selected: _selectedType == 'expiry_check',
                    onTap: () => setState(() => _selectedType = 'expiry_check'),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(pendingReviewProvider),
              child: pendingAsync.when(
                data: (observations) {
                  final filtered = _selectedType == 'all'
                      ? observations
                      : observations.where((o) => o.type == _selectedType).toList();

                  if (filtered.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: 360,
                          child: EmptyState(
                            title: 'Nothing to review',
                            message: _selectedType == 'all'
                                ? 'Pending stock count and expiry submissions will appear here.'
                                : 'No pending ${_selectedType == 'stock_count' ? 'stock counts' : 'expiry checks'} found.',
                            icon: Icons.fact_check_outlined,
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final obs = filtered[index];
                      return AppCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 10,
                        ),
                        onTap: () => context.push('/review/${obs.id}', extra: obs),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    obs.itemName ?? 'Item #${obs.itemId}',
                                    style: AppTextStyles.bodyStrong.copyWith(fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    obs.type == 'stock_count' ? 'Stock Count' : 'Expiry Check',
                                    style: AppTextStyles.caption.copyWith(
                                      fontSize: 11,
                                      color: AppColors.primaryBlue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (obs.createdAt != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '${obs.createdAt!.day}/${obs.createdAt!.month}/${obs.createdAt!.year}',
                                      style: AppTextStyles.caption.copyWith(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            VarianceIndicator(variance: obs.variance),
                            const SizedBox(width: AppSpacing.md),
                            StatusBadge.fromString(obs.status, compact: true),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const ShimmerListPlaceholder(),
                error: (e, _) => ErrorState(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(pendingReviewProvider),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryBlue : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primaryBlue : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
