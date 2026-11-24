import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../state/notification_providers.dart';

class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  static final _dateFormat = DateFormat('dd MMM, hh:mm a');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () => ref.read(notificationProvider.notifier).markAllRead(),
              child: const Text(
                'Mark all read',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(notificationProvider.notifier).refresh(),
        child: state.isLoading && state.notifications.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : state.notifications.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.notifications_none_rounded,
                              size: 56,
                              color: AppColors.textMuted,
                            ),
                            SizedBox(height: AppSpacing.sm),
                            Text(
                              'No notifications yet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'When you receive task assignments or recount alerts, they will appear here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: state.notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = state.notifications[index];
                      final isTask = item.type == 'task_assigned';
                      final isRecount = item.type == 'recount_requested';

                      return AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        color: item.isRead
                            ? AppColors.surface
                            : AppColors.primaryBlue.withValues(alpha: 0.05),
                        onTap: () {
                          if (!item.isRead) {
                            ref.read(notificationProvider.notifier).markRead(item.id);
                          }
                          // Navigate if task_id present
                          if (item.data != null && item.data!['task_id'] != null) {
                            final taskId = item.data!['task_id'].toString();
                            context.push('/tasks/$taskId');
                          }
                        },
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isTask
                                    ? AppColors.primaryBlue.withValues(alpha: 0.12)
                                    : (isRecount
                                        ? AppColors.warningBg
                                        : AppColors.surfaceAlt),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isTask
                                    ? Icons.assignment_turned_in_rounded
                                    : (isRecount
                                        ? Icons.replay_rounded
                                        : Icons.notifications_active_rounded),
                                size: 20,
                                color: isTask
                                    ? AppColors.primaryBlue
                                    : (isRecount
                                        ? AppColors.warning
                                        : AppColors.navy),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.title,
                                          style: AppTextStyles.bodyStrong.copyWith(
                                            color: item.isRead
                                                ? AppColors.textPrimary
                                                : AppColors.navy,
                                            fontWeight: item.isRead
                                                ? FontWeight.w600
                                                : FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      if (!item.isRead)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: AppColors.primaryBlue,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    item.message,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  if (item.createdAt != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      _dateFormat.format(item.createdAt!.toLocal()),
                                      style: AppTextStyles.caption.copyWith(
                                        fontSize: 10,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

