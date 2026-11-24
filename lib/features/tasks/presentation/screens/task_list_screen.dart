import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../auth/state/auth_providers.dart';
import '../../state/task_providers.dart';

/// Task list. Staff: tasks assigned to them (server-scoped). Manager/Owner:
/// every task in their branch(es), filterable by product Category / Brand,
/// plus an "Assign" action that opens [CreateTaskScreen].
class TaskListScreen extends ConsumerWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(myTasksProvider);
    final isManager =
        ref.watch(authControllerProvider).user?.isManagerOrOwner ?? false;
    final filter = ref.watch(taskListFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isManager ? 'Tasks' : 'My Tasks'),
        actions: [
          if (isManager)
            TextButton.icon(
              key: const Key('task-list-assign'),
              onPressed: () => context.push('/tasks/new'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(Icons.add_task_rounded),
              label: const Text('Assign'),
            ),
        ],
      ),
      body: Column(
        children: [
          if (isManager) _TaskFilterBar(filter: filter),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(myTasksProvider),
              child: tasksAsync.when(
                data: (tasks) {
                  if (tasks.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: 360,
                          child: EmptyState(
                            title: filter.isActive
                                ? 'No tasks match this filter'
                                : (isManager
                                      ? 'No tasks yet'
                                      : 'No tasks assigned'),
                            message: isManager
                                ? 'Assign a count task by branch, section, category or brand.'
                                : 'Tasks assigned to you by your manager will appear here.',
                            icon: Icons.assignment_outlined,
                            actionLabel: isManager ? 'Assign Task' : null,
                            onAction: isManager
                                ? () => context.push('/tasks/new')
                                : null,
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    itemCount: tasks.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _TaskCard(task: tasks[index], showAssignee: isManager),
                  );
                },
                loading: () => const LoadingState(),
                error: (e, _) => ErrorState(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(myTasksProvider),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskFilterBar extends ConsumerWidget {
  const _TaskFilterBar({required this.filter});

  final TaskListFilter filter;

  Future<void> _choose<T>(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required AsyncValue<List<T>> async,
    required String Function(T) id,
    required String Function(T) name,
    required String? current,
    required TaskListFilter Function(String?) apply,
  }) async {
    final items = async.value ?? const [];
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.6,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(title, style: AppTextStyles.h3),
            ),
            ListTile(
              title: const Text('All'),
              trailing: current == null ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(context).pop(''),
            ),
            for (final item in items)
              ListTile(
                title: Text(name(item)),
                trailing: current == id(item) ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(id(item)),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    ref.read(taskListFilterProvider.notifier).state = apply(
      picked.isEmpty ? null : picked,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final brandsAsync = ref.watch(brandsProvider);

    String? nameOf<T>(
      AsyncValue<List<T>> async,
      String? id,
      String Function(T) idOf,
      String Function(T) nameOfItem,
    ) {
      if (id == null) return null;
      for (final item in async.value ?? <T>[]) {
        if (idOf(item) == id) return nameOfItem(item);
      }
      return 'Selected';
    }

    final categoryLabel = nameOf<CategoryModel>(
      categoriesAsync,
      filter.categoryValueId,
      (c) => c.id,
      (c) => c.name,
    );
    final brandLabel = nameOf<BrandModel>(
      brandsAsync,
      filter.brandId,
      (b) => b.id,
      (b) => b.name,
    );

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          FilterChip(
            key: const Key('task-filter-category'),
            label: Text(categoryLabel ?? 'Category'),
            selected: filter.categoryValueId != null,
            onSelected: (_) => _choose<CategoryModel>(
              context,
              ref,
              title: 'Filter by category',
              async: categoriesAsync,
              id: (c) => c.id,
              name: (c) => c.name,
              current: filter.categoryValueId,
              apply: (v) =>
                  TaskListFilter(categoryValueId: v, brandId: filter.brandId),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilterChip(
            key: const Key('task-filter-brand'),
            label: Text(brandLabel ?? 'Brand'),
            selected: filter.brandId != null,
            onSelected: (_) => _choose<BrandModel>(
              context,
              ref,
              title: 'Filter by brand',
              async: brandsAsync,
              id: (b) => b.id,
              name: (b) => b.name,
              current: filter.brandId,
              apply: (v) => TaskListFilter(
                categoryValueId: filter.categoryValueId,
                brandId: v,
              ),
            ),
          ),
          const Spacer(),
          if (filter.isActive)
            TextButton(
              onPressed: () => ref.read(taskListFilterProvider.notifier).state =
                  const TaskListFilter(),
              child: const Text('Clear'),
            ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.showAssignee});

  final TaskModel task;
  final bool showAssignee;

  @override
  Widget build(BuildContext context) {
    final scope = [
      if (task.categoryName != null) task.categoryName!,
      if (task.brandName != null) task.brandName!,
      if (task.section != null) task.section!,
    ].join(' · ');

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 10,
      ),
      onTap: () => context.push('/tasks/${task.id}'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: AppTextStyles.bodyStrong.copyWith(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (scope.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    scope,
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (showAssignee && task.assigneeName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Assigned to ${task.assigneeName}',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    _PriorityChip(priority: task.priority),
                    if (task.dueDate != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      const Icon(
                        Icons.event,
                        size: 12,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${task.dueDate!.day}/${task.dueDate!.month}/${task.dueDate!.year}',
                        style: AppTextStyles.caption.copyWith(fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          StatusBadge.fromString(task.status, compact: true),
        ],
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority});
  final String priority;

  @override
  Widget build(BuildContext context) {
    final color = switch (priority) {
      'high' => AppColors.critical,
      'low' => AppColors.textMuted,
      _ => AppColors.info,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        priority.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
