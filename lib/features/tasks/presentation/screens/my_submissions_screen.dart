import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../review/state/review_providers.dart';

/// "My submissions / history" screen — staff can see their own past
/// observations and current review status, but never system quantity.
class MySubmissionsScreen extends ConsumerWidget {
  const MySubmissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final observationsAsync = ref.watch(myObservationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My Submissions')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myObservationsProvider),
        child: observationsAsync.when(
          data: (observations) {
            if (observations.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(
                    height: 360,
                    child: EmptyState(
                      title: 'No submissions yet',
                      message:
                          'Stock counts and expiry checks you submit will show up here.',
                      icon: Icons.history_rounded,
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
              itemCount: observations.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final obs = observations[index];
                return AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: obs.type == 'stock_count'
                              ? AppColors.infoBg
                              : AppColors.successBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (obs.type == 'stock_count'
                                    ? AppColors.info
                                    : AppColors.success)
                                .withValues(alpha: 0.18),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          obs.type == 'stock_count'
                              ? Icons.inventory_2_outlined
                              : Icons.event_busy_outlined,
                          size: 18,
                          color: obs.type == 'stock_count'
                              ? AppColors.info
                              : AppColors.success,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
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
                              '${obs.type == 'stock_count' ? 'Stock Count' : 'Expiry Check'} · Batch ${obs.batchNo ?? '-'}',
                              style: AppTextStyles.caption.copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
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
            onRetry: () => ref.invalidate(myObservationsProvider),
          ),
        ),
      ),
    );
  }
}
