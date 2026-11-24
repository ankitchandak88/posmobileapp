import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../auth/state/auth_providers.dart';
import '../../state/task_providers.dart';

/// Task details (`GET /v1/tasks/{id}`): context (branch, section, category,
/// brand, assignee, due date, priority), the products in scope, and the
/// role-appropriate actions — start/complete (assignee), cancel
/// (Manager/Owner), and launching a stock count / expiry check.
///
/// No system quantity is shown here for anyone: the server strips
/// `system_qty_snapshot` from a Staff caller's task payload, and this screen
/// never renders it for any role.
class TaskDetailScreen extends ConsumerStatefulWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  bool _updatingStatus = false;

  /// Calls `PATCH /v1/tasks/{task}/status`. Surfaces a server rejection
  /// (422 invalid transition, 403 wrong actor) as a clear snackbar message
  /// instead of failing silently, and refreshes the task list/detail on
  /// success.
  Future<void> _transition(String newStatus) async {
    setState(() => _updatingStatus = true);
    try {
      await ref
          .read(taskRepositoryProvider)
          .updateStatus(widget.taskId, newStatus);
      ref.invalidate(myTasksProvider);
      ref.invalidate(taskByIdProvider(widget.taskId));
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException
          ? e.message
          : 'Could not update task status: $e';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskAsync = ref.watch(taskByIdProvider(widget.taskId));
    final currentUser = ref.watch(authControllerProvider).user;

    return Scaffold(
      appBar: AppBar(title: const Text('Task Details')),
      body: taskAsync.when(
        data: (task) {
          if (task == null) {
            return const EmptyState(
              title: 'Task not found',
              icon: Icons.search_off,
            );
          }

          final isAssignee =
              currentUser != null && currentUser.id == task.assignedTo;
          final isManager = currentUser?.isManagerOrOwner ?? false;
          final canStart = isAssignee && task.status == 'pending';
          final canComplete = isAssignee && task.status == 'in_progress';
          final canCancel =
              isManager &&
              (task.status == 'pending' || task.status == 'in_progress');
          final isOpen =
              task.status == 'pending' || task.status == 'in_progress';

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(task.title, style: AppTextStyles.h2),
                        ),
                        StatusBadge.fromString(task.status),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _DetailRow(
                      label: 'Branch',
                      value: task.branchName ?? task.branchId,
                    ),
                    if (task.section != null)
                      _DetailRow(label: 'Section / Rack', value: task.section!),
                    if (task.categoryName != null)
                      _DetailRow(label: 'Category', value: task.categoryName!),
                    if (task.brandName != null)
                      _DetailRow(label: 'Brand', value: task.brandName!),
                    if (task.assigneeName != null)
                      _DetailRow(
                        label: 'Assigned to',
                        value: task.assigneeName!,
                      ),
                    if (task.assignerName != null)
                      _DetailRow(
                        label: 'Assigned by',
                        value: task.assignerName!,
                      ),
                    _DetailRow(
                      label: 'Priority',
                      value: task.priority.toUpperCase(),
                    ),
                    if (task.dueDate != null)
                      _DetailRow(
                        label: 'Due date',
                        value:
                            '${task.dueDate!.day}/${task.dueDate!.month}/${task.dueDate!.year}',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _ScopeCard(task: task),
              const SizedBox(height: AppSpacing.xl),
              if (canStart) ...[
                AppButton(
                  label: 'Mark In Progress',
                  icon: Icons.play_circle_outline,
                  loading: _updatingStatus,
                  onPressed: _updatingStatus
                      ? null
                      : () => _transition('in_progress'),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (canComplete) ...[
                AppButton(
                  label: 'Mark Complete',
                  icon: Icons.check_circle_outline,
                  loading: _updatingStatus,
                  onPressed: _updatingStatus
                      ? null
                      : () => _transition('completed'),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (isOpen) ...[
                AppButton(
                  label: 'Start Stock Count',
                  variant: canStart || canComplete
                      ? AppButtonVariant.secondary
                      : AppButtonVariant.primary,
                  icon: Icons.qr_code_scanner_rounded,
                  onPressed: () => context.push(
                    '/scanner',
                    extra: {'mode': 'stock_count', 'taskId': task.id},
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Start Expiry Check',
                  variant: AppButtonVariant.secondary,
                  icon: Icons.event_busy_rounded,
                  onPressed: () => context.push(
                    '/scanner',
                    extra: {'mode': 'expiry_check', 'taskId': task.id},
                  ),
                ),
              ],
              if (canCancel) ...[
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Cancel Task',
                  variant: AppButtonVariant.danger,
                  icon: Icons.cancel_outlined,
                  loading: _updatingStatus,
                  onPressed: _updatingStatus
                      ? null
                      : () => _transition('cancelled'),
                ),
              ],
            ],
          );
        },
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(taskByIdProvider(widget.taskId)),
        ),
      ),
    );
  }
}

/// "Products to count": the explicitly selected products if any; otherwise,
/// for a category/brand-scoped task, the products that scope resolves to
/// (first page from `GET /v1/items/search?category_value_id=&brand_id=`).
class _ScopeCard extends ConsumerWidget {
  const _ScopeCard({required this.task});

  final TaskModel task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget body;
    if (task.items.isNotEmpty) {
      final targetIds = {
        for (final i in task.items)
          if (i.itemId != null) i.itemId!,
      };
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TaskProgress(
            counted: targetIds.where(task.observedItemIds.contains).length,
            total: targetIds.length,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final item in task.items)
            _ProductLine(
              name: item.itemName ?? 'Item #${item.itemId ?? '-'}',
              detail: [
                if (item.itemCode != null) item.itemCode!,
                if (item.batchNo != null) 'Batch ${item.batchNo}',
              ].join(' · '),
              counted:
                  item.itemId != null &&
                  task.observedItemIds.contains(item.itemId),
            ),
        ],
      );
    } else if (task.hasCategoryOrBrandScope) {
      final scopeAsync = ref.watch(
        scopeItemsProvider((
          categoryValueId: task.categoryValueId,
          brandId: task.brandId,
          query: '',
        )),
      );
      body = scopeAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: LinearProgressIndicator(minHeight: 2),
        ),
        error: (e, _) => Text(
          'Could not load products: $e',
          style: const TextStyle(color: AppColors.critical, fontSize: 12),
        ),
        data: (page) {
          if (page.items.isEmpty) {
            return const Text(
              'No active products match this category/brand.',
              style: AppTextStyles.caption,
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TaskProgress(
                counted: task.observedItemIds.length > page.total
                    ? page.total
                    : task.observedItemIds.length,
                total: page.total,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${page.total} product${page.total == 1 ? '' : 's'} in scope',
                key: const Key('task-scope-total'),
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: AppSpacing.xs),
              for (final item in page.items.take(10))
                _ProductLine(
                  name: item.name,
                  detail: item.sku,
                  counted: task.observedItemIds.contains(item.id),
                ),
              if (page.total > 10)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    '+ ${page.total - 10} more — scan or search to count them.',
                    style: AppTextStyles.caption,
                  ),
                ),
            ],
          );
        },
      );
    } else {
      body = Text(
        'Open task — count any product in this branch/section. '
        '${task.observationCount} submission${task.observationCount == 1 ? '' : 's'} so far.',
        key: const Key('task-open-progress'),
        style: AppTextStyles.caption,
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Products to count', style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.sm),
          body,
        ],
      ),
    );
  }
}

/// "x of N products counted" bar (master prompt §7 "Task progress"). Based on
/// distinct products that have at least one submission on this task — a
/// submission, not an approval, so it measures counting progress only.
class TaskProgress extends StatelessWidget {
  const TaskProgress({super.key, required this.counted, required this.total});

  final int counted;
  final int total;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : counted / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$counted of $total product${total == 1 ? '' : 's'} counted',
          key: const Key('task-progress-label'),
          style: AppTextStyles.bodyStrong,
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: AppColors.surfaceAlt,
            color: fraction >= 1 ? AppColors.success : AppColors.primaryBlue,
          ),
        ),
      ],
    );
  }
}

class _ProductLine extends StatelessWidget {
  const _ProductLine({
    required this.name,
    required this.detail,
    this.counted = false,
  });

  final String name;
  final String detail;
  final bool counted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(
            counted ? Icons.check_circle_rounded : Icons.inventory_2_outlined,
            size: 18,
            color: counted ? AppColors.success : AppColors.textMuted,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              name,
              style: AppTextStyles.bodyStrong,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (detail.isNotEmpty) Text(detail, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              value,
              style: AppTextStyles.bodyStrong,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
