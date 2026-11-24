import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/widgets/role_switch_sheet.dart';
import '../../../auth/state/auth_providers.dart';
import '../widgets/delivery_order_card.dart';
import '../../state/rider_order_providers.dart';

class RiderDeliveriesScreen extends ConsumerWidget {
  const RiderDeliveriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final riderState = ref.watch(riderOrdersProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () async {
            if (authState.hasLinkedStaff) {
              await ref
                  .read(authControllerProvider.notifier)
                  .switchRole('store_staff');
              if (context.mounted) {
                try {
                  context.go('/home');
                } catch (_) {}
              }
            } else if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              try {
                context.go('/home');
              } catch (_) {}
            }
          },
        ),
        automaticallyImplyLeading: false,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.two_wheeler_rounded,
                color: AppColors.warning,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user != null && user.name.isNotEmpty
                        ? 'Hi, ${user.name}'
                        : 'Delivery Partner',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    'Today\'s Deliveries',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('rider_switch_store_button'),
            tooltip: authState.hasLinkedStaff
                ? 'Switch to Store Staff'
                : 'Connect Store Staff',
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.storefront_rounded, size: 16, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'Store',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            onPressed: () async {
              if (authState.hasLinkedStaff) {
                await ref
                    .read(authControllerProvider.notifier)
                    .switchRole('store_staff');
                if (context.mounted) {
                  try {
                    context.go('/home');
                  } catch (_) {}
                }
              } else {
                RoleSwitchSheet.show(context);
              }
            },
          ),
          IconButton(
            key: const Key('rider_refresh_button'),
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () =>
                ref.read(riderOrdersProvider.notifier).loadDeliveries(),
          ),
          IconButton(
            key: const Key('rider_logout_button'),
            tooltip: 'Logout / Switch Role',
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            onPressed: () async {
              if (authState.hasLinkedStaff) {
                // If staff account is also linked, offer role switch or sign out
                final action = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Rider Session'),
                    content: const Text(
                      'Do you want to switch to Store Staff or sign out?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop('cancel'),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop('switch'),
                        child: const Text(
                          'Switch to Store',
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.critical,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.of(ctx).pop('logout_rider'),
                        child: const Text('Sign Out'),
                      ),
                    ],
                  ),
                );

                if (action == 'switch') {
                  await ref
                      .read(authControllerProvider.notifier)
                      .switchRole('store_staff');
                  if (context.mounted) {
                    try {
                      context.go('/home');
                    } catch (_) {}
                  }
                } else if (action == 'logout_rider') {
                  await ref
                      .read(authControllerProvider.notifier)
                      .logout(keepSavedAccounts: true);
                  if (context.mounted) {
                    try {
                      context.go('/login');
                    } catch (_) {}
                  }
                }
                return;
              }

              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.critical,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref
                    .read(authControllerProvider.notifier)
                    .logout(keepSavedAccounts: true);
                if (context.mounted) {
                  try {
                    context.go('/login');
                  } catch (_) {}
                }
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(riderOrdersProvider.notifier).loadDeliveries(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Summary Cards Header
            SliverToBoxAdapter(
              child: Container(
                color: AppColors.navy,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSummaryPill(
                        label: 'Assigned',
                        count: riderState.assignedCount,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: _buildSummaryPill(
                        label: 'Out for Delivery',
                        count: riderState.outForDeliveryCount,
                        color: Colors.lightBlueAccent,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: _buildSummaryPill(
                        label: 'Completed',
                        count: riderState.deliveredCount,
                        color: Colors.greenAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Filter Tabs Row
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        ref: ref,
                        keyStr: 'all',
                        label: 'All (${riderState.totalCount})',
                        current: riderState.selectedTab,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _buildFilterChip(
                        ref: ref,
                        keyStr: 'assigned',
                        label: 'Assigned (${riderState.assignedCount})',
                        current: riderState.selectedTab,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _buildFilterChip(
                        ref: ref,
                        keyStr: 'out_for_delivery',
                        label: 'Out (${riderState.outForDeliveryCount})',
                        current: riderState.selectedTab,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _buildFilterChip(
                        ref: ref,
                        keyStr: 'delivered',
                        label: 'Delivered (${riderState.deliveredCount})',
                        current: riderState.selectedTab,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Error banner if any
            if (riderState.errorMessage != null)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.criticalBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.critical),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.critical, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          riderState.errorMessage!,
                          style: const TextStyle(color: AppColors.critical, fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: () => ref
                            .read(riderOrdersProvider.notifier)
                            .loadDeliveries(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),

            // Content List
            if (riderState.isLoading && riderState.orders.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (riderState.filteredOrders.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.local_shipping_outlined,
                        size: 64,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'No deliveries in this section',
                        style: AppTextStyles.h3.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Pull down to refresh or check back later.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.xl,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final order = riderState.filteredOrders[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: DeliveryOrderCard(
                          order: order,
                          onStartDelivery: (orderId, km) async {
                            final success = await ref
                                .read(riderOrdersProvider.notifier)
                                .startDelivery(orderId, km);
                            if (context.mounted && success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Delivery started! Drive safely.'),
                                  backgroundColor: AppColors.primaryBlue,
                                ),
                              );
                            }
                          },
                          onMarkDelivered: (orderId, km, [notes]) async {
                            final success = await ref
                                .read(riderOrdersProvider.notifier)
                                .markDelivered(orderId, km, notes: notes);
                            if (context.mounted && success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(notes != null
                                      ? 'Delivered! Note: $notes'
                                      : 'Order delivered successfully! Great job.'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          },
                          onAssignVehicle: (orderId, vehicleId, regNo) async {
                            final success = await ref
                                .read(riderOrdersProvider.notifier)
                                .assignVehicle(
                                  orderId,
                                  vehicleId,
                                  registrationNumber: regNo,
                                );
                            if (context.mounted && success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Vehicle $regNo assigned to Bill #${order.invoiceNo}!'),
                                  backgroundColor: AppColors.primaryBlue,
                                ),
                              );
                            }
                            return success;
                          },
                        ),
                      );
                    },
                    childCount: riderState.filteredOrders.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryPill({
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required WidgetRef ref,
    required String keyStr,
    required String label,
    required String current,
  }) {
    final selected = current == keyStr;
    return GestureDetector(
      key: Key('rider_tab_$keyStr'),
      onTap: () => ref.read(riderOrdersProvider.notifier).setTab(keyStr),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryBlue : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primaryBlue : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textPrimary,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
