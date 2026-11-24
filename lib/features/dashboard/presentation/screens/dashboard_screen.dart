import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../auth/presentation/widgets/role_switch_sheet.dart';
import '../../../auth/state/auth_providers.dart';
import '../../../notifications/state/notification_providers.dart';
import '../../state/dashboard_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final branchesAsync = ref.watch(branchesProvider);
    final dashboardAsync = ref.watch(dashboardSummaryProvider);
    final isManager = auth.user?.isManagerOrOwner ?? false;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(branchesProvider);
          ref.invalidate(dashboardSummaryProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              backgroundColor: AppColors.navy,
              pinned: true,
              toolbarHeight: 60,
              automaticallyImplyLeading: false,
              titleSpacing: AppSpacing.md,
              title: Row(
                children: [
                  Image.asset(
                    'assets/branding/logo_white.png',
                    height: 28,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: branchesAsync.maybeWhen(
                      data: (branches) {
                        final selected =
                            ref.watch(selectedBranchIdProvider) ??
                            auth.user?.branchId ??
                            (branches.isNotEmpty ? branches.first.id : null);
                        return Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22),
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selected,
                                dropdownColor: AppColors.navy,
                                isDense: true,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Colors.white70,
                                  size: 16,
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                items: branches
                                    .map(
                                      (b) => DropdownMenuItem(
                                        value: b.id,
                                        child: Text(
                                          b.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) =>
                                    ref
                                            .read(selectedBranchIdProvider.notifier)
                                            .state =
                                        val,
                              ),
                            ),
                          ),
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
              actions: [
                Consumer(
                  builder: (context, ref, _) {
                    final authState = ref.watch(authControllerProvider);
                    return IconButton(
                      key: const Key('dashboard_role_switch_button'),
                      tooltip: authState.hasLinkedRider
                          ? 'Switch to Delivery Rider'
                          : 'Connect Delivery Rider',
                      icon: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.two_wheeler_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      onPressed: () async {
                        if (authState.hasLinkedRider) {
                          await ref
                              .read(authControllerProvider.notifier)
                              .switchRole('rider');
                          if (context.mounted) {
                            try {
                              context.go('/rider-deliveries');
                            } catch (_) {}
                          }
                        } else {
                          RoleSwitchSheet.show(context);
                        }
                      },
                    );
                  },
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final unread = ref.watch(notificationProvider).unreadCount;
                    return IconButton(
                      icon: Badge(
                        isLabelVisible: unread > 0,
                        label: Text('$unread'),
                        backgroundColor: AppColors.critical,
                        child: const Icon(
                          Icons.notifications_outlined,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      onPressed: () => context.push('/notifications'),
                    );
                  },
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Compact Search Bar with Embedded Barcode Scanner
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(AppSpacing.radiusMd),
                              ),
                              onTap: () => context.push(
                                '/product-search',
                                extra: {'mode': 'stock_count'},
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.search,
                                      color: AppColors.textMuted,
                                      size: 18,
                                    ),
                                    SizedBox(width: AppSpacing.sm),
                                    Text(
                                      'Search product, SKU or barcode…',
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 20,
                            color: AppColors.border,
                          ),
                          IconButton(
                            tooltip: 'Scan Barcode',
                            icon: const Icon(
                              Icons.qr_code_scanner_rounded,
                              color: AppColors.primaryBlue,
                              size: 20,
                            ),
                            onPressed: () => context.push(
                              '/scanner',
                              extra: {'mode': 'view'},
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Quick Actions Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Quick Actions', style: AppTextStyles.h3),
                        Text(
                          'Handheld Tools',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.sm,
                      childAspectRatio: 1.45,
                      children: [
                        _DashboardTile(
                          label: 'Supplier Inward',
                          subtitle: 'Receive & add stock',
                          icon: Icons.local_shipping_rounded,
                          color: AppColors.primaryBlue,
                          onTap: () => context.push('/inward-entry'),
                        ),
                        _DashboardTile(
                          label: 'Stock & Expiry Check',
                          subtitle: 'Scan count & expiry',
                          icon: Icons.checklist_rtl_rounded,
                          color: AppColors.primaryBlue,
                          onTap: () => context.push(
                            '/scanner',
                            extra: {'mode': 'stock_count'},
                          ),
                        ),
                        _DashboardTile(
                          label: 'Quick Item View',
                          subtitle: 'Check details',
                          icon: Icons.visibility_rounded,
                          color: AppColors.primaryBlue,
                          onTap: () => context.push(
                            '/product-search',
                            extra: {'mode': 'view'},
                          ),
                        ),
                        _DashboardTile(
                          label: 'Purchase Lookup',
                          subtitle: 'Barcode & cost check',
                          icon: Icons.receipt_long_rounded,
                          color: AppColors.primaryBlue,
                          onTap: () => context.push('/purchase-lookup'),
                        ),
                        _DashboardTile(
                          label: 'Rider Deliveries',
                          subtitle: 'Live tracking & status',
                          icon: Icons.two_wheeler_rounded,
                          color: AppColors.warning,
                          onTap: () async {
                            final authState = ref.read(authControllerProvider);
                            if (authState.hasLinkedRider) {
                              await ref
                                  .read(authControllerProvider.notifier)
                                  .switchRole('rider');
                              if (context.mounted) {
                                try {
                                  context.go('/rider-deliveries');
                                } catch (_) {}
                              }
                            } else {
                              RoleSwitchSheet.show(context);
                            }
                          },
                        ),
                        if (isManager) ...[
                          _DashboardTile(
                            label: 'Approval Queue',
                            subtitle: 'Review submissions',
                            icon: Icons.fact_check_rounded,
                            color: AppColors.primaryBlue,
                            onTap: () => context.push('/review'),
                          ),
                          _DashboardTile(
                            label: 'Assign Task',
                            subtitle: 'By rack/category',
                            icon: Icons.add_task_rounded,
                            color: AppColors.primaryBlue,
                            onTap: () => context.push('/tasks/new'),
                          ),
                          _DashboardTile(
                            label: 'Barcode Requests',
                            subtitle: 'Unknown barcodes',
                            icon: Icons.qr_code_2_rounded,
                            color: AppColors.primaryBlue,
                            onTap: () => context.push('/barcode-mapping/review'),
                          ),
                          _DashboardTile(
                            label: 'Expiry Settings',
                            subtitle: 'Exposure buckets',
                            icon: Icons.tune_rounded,
                            color: AppColors.primaryBlue,
                            onTap: () => context.push('/expiry-bucket-settings'),
                          ),
                        ] else
                          _DashboardTile(
                            label: 'My Tasks',
                            subtitle: 'Pending & done',
                            icon: Icons.assignment_rounded,
                            color: AppColors.primaryBlue,
                            onTap: () => context.go('/tasks'),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Today's Overview
                    Text("Today's Overview", style: AppTextStyles.h3),
                    const SizedBox(height: AppSpacing.xs),
                    dashboardAsync.when(
                      data: (summary) {
                        final tasks = summary.taskCounts;
                        final totalTasks =
                            tasks.pending + tasks.inProgress + tasks.completed;
                        final completionRatio =
                            totalTasks > 0 ? (tasks.completed / totalTasks) : 0.0;
                        final percentage = (completionRatio * 100).round();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // High-Density Overview Card
                            AppCard(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      // Circular Progress indicator
                                      SizedBox(
                                        width: 54,
                                        height: 54,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            CircularProgressIndicator(
                                              value: totalTasks > 0
                                                  ? completionRatio
                                                  : 0.0,
                                              strokeWidth: 5,
                                              backgroundColor:
                                                  AppColors.surfaceAlt,
                                              valueColor:
                                                  const AlwaysStoppedAnimation<Color>(
                                                AppColors.primaryBlue,
                                              ),
                                            ),
                                            Text(
                                              '$percentage%',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.primaryBlue,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                _MiniPill(
                                                  label: 'Pending',
                                                  count: tasks.pending,
                                                  color: AppColors.warning,
                                                  icon: Icons.schedule_rounded,
                                                ),
                                                const SizedBox(width: 6),
                                                _MiniPill(
                                                  label: 'Done',
                                                  count: tasks.completed,
                                                  color: AppColors.success,
                                                  icon: Icons.check_circle_outline,
                                                ),
                                                const SizedBox(width: 6),
                                                _MiniPill(
                                                  label: 'Active',
                                                  count: tasks.inProgress,
                                                  color: AppColors.info,
                                                  icon: Icons.sync_rounded,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              totalTasks > 0
                                                  ? '${tasks.completed} of $totalTasks tasks finished today'
                                                  : 'No tasks scheduled today',
                                              style: AppTextStyles.caption.copyWith(
                                                fontSize: 11,
                                                color: AppColors.textMuted,
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
                            // Manager/Owner-only tiles
                            if (summary.pendingReviewCount != null) ...[
                              const SizedBox(height: AppSpacing.sm),
                              AppCard(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.pending_actions_rounded,
                                      color: AppColors.warning,
                                      size: 18,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        'Pending Review Queue',
                                        style: AppTextStyles.bodyStrong,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.warningBg,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${summary.pendingReviewCount}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.warning,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (summary.expiryBuckets != null &&
                                summary.expiryBuckets!.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.md),
                              Text('Expiry Exposure', style: AppTextStyles.h3),
                              const SizedBox(height: AppSpacing.xs),
                              ...summary.expiryBuckets!.map(
                                (bucket) => Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: 6,
                                  ),
                                  child: _ExpiryBucketRow(bucket: bucket),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                      loading: () => const LoadingState(),
                      error: (e, _) => ErrorState(message: e.toString()),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



class _MiniPill extends StatelessWidget {
  const _MiniPill({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  final String label;
  final int count;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 10, color: color),
                const SizedBox(width: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 1),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  const _DashboardTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.22),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Manager/Owner-only row summarizing one `expiry_buckets` entry from
/// `GET /v1/dashboard/summary`.
/// Tapping it opens the items list for checking expiry.
class _ExpiryBucketRow extends StatelessWidget {
  const _ExpiryBucketRow({required this.bucket});

  final DashboardExpiryBucket bucket;

  Color _severityColor() {
    switch (bucket.severity) {
      case 'critical':
        return AppColors.critical;
      case 'warning':
        return AppColors.warning;
      default:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: () {
          context.push(
            '/product-search',
            extra: {
              'mode': 'expiry_check',
              'title': '${bucket.label} (${bucket.count} items)',
            },
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _severityColor(),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bucket.label, style: AppTextStyles.bodyStrong),
                    Text(
                      'Tap to view & verify expiry',
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _severityColor().withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  bucket.hasMore ? '${bucket.count}+ items' : '${bucket.count} items',
                  style: TextStyle(
                    color: _severityColor(),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
