import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../dashboard/state/dashboard_providers.dart';
import '../../state/history_providers.dart';

/// "History & Audit" — dedicated screen matching
/// UrbanPets_Premium_UI_HD/10_history_audit_3x.png:
///
///   app bar (back · "History & Audit" · filter action)
///   Branch dropdown  |  Date Range picker
///   [ All | Stock Count | Expiry Check ] segmented tabs
///   rows: product tile · name · date/time · submitter · signed variance · status pill
///
/// One screen, two server-enforced data scopes:
/// - Manager/Owner → `GET /v1/observations` (every submitter in their
///   permitted branches; variance + submitter shown; Owner can pick any
///   branch or "All Branches").
/// - Staff → `GET /v1/observations/mine` (own rows only, blind: no variance
///   column is rendered and the server never sends one).
///
/// Lists are paginated (20/page) with infinite scroll.
class HistoryAuditScreen extends ConsumerStatefulWidget {
  const HistoryAuditScreen({super.key});

  @override
  ConsumerState<HistoryAuditScreen> createState() => _HistoryAuditScreenState();
}

class _HistoryAuditScreenState extends ConsumerState<HistoryAuditScreen> {
  final _scrollController = ScrollController();

  static final _rangeFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      ref.read(historyControllerProvider.notifier).loadMore();
    }
  }

  void _update(HistoryFilters Function(HistoryFilters) change) {
    ref.read(historyControllerProvider.notifier).updateFilters(change);
  }

  Future<void> _pickDateRange(HistoryFilters current) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: current.hasDateRange
          ? DateTimeRange(start: current.dateFrom!, end: current.dateTo!)
          : null,
      helpText: 'Submission date range',
    );
    if (picked != null) {
      _update((f) => f.copyWith(dateFrom: picked.start, dateTo: picked.end));
    }
  }

  Future<void> _pickStatus(HistoryFilters current) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        // Scrollable so the sheet never overflows on short screens /
        // landscape / large text scale.
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text('Filter by status', style: AppTextStyles.h3),
            ),
            _StatusOption(
              label: 'All statuses',
              selected: current.status == null,
              onTap: () => Navigator.of(context).pop(''),
            ),
            for (final entry in historyStatuses.entries)
              _StatusOption(
                label: entry.value,
                selected: current.status == entry.key,
                onTap: () => Navigator.of(context).pop(entry.key),
              ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
    if (selected == null) return; // dismissed
    _update(
      (f) => selected.isEmpty
          ? f.copyWith(clearStatus: true)
          : f.copyWith(status: selected),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyControllerProvider);
    final controller = ref.read(historyControllerProvider.notifier);
    final isReviewer = controller.asReviewer;
    final branchesAsync = ref.watch(branchesProvider);
    final filters = state.filters;

    return Scaffold(
      appBar: AppBar(
        title: const Text('History & Audit'),
        actions: [
          IconButton(
            key: const Key('history-status-filter'),
            tooltip: 'Filter by status',
            onPressed: () => _pickStatus(filters),
            icon: Badge(
              isLabelVisible: filters.status != null,
              smallSize: 8,
              child: const Icon(Icons.manage_search_rounded),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _FilterField(
                        label: 'Branch',
                        child: branchesAsync.when(
                          data: (branches) => _BranchDropdown(
                            branches: branches,
                            value: filters.branchId,
                            // Staff and branch-scoped Managers only get their
                            // own branch from /branches (server-scoped), so the
                            // dropdown just shows that branch, locked.
                            allLabel: branches.length == 1
                                ? branches.first.name
                                : 'All Branches',
                            onChanged: (id) => _update(
                              (f) => id == null
                                  ? f.copyWith(clearBranch: true)
                                  : f.copyWith(branchId: id),
                            ),
                          ),
                          loading: () => const _FieldText('Loading…'),
                          error: (_, _) => const _FieldText('All Branches'),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _FilterField(
                        label: 'Date Range',
                        child: InkWell(
                          key: const Key('history-date-range'),
                          onTap: () => _pickDateRange(filters),
                          child: Row(
                            children: [
                              Expanded(
                                child: _FieldText(
                                  filters.hasDateRange
                                      ? '${_rangeFormat.format(filters.dateFrom!)} - ${_rangeFormat.format(filters.dateTo!)}'
                                      : 'All dates',
                                ),
                              ),
                              if (filters.hasDateRange)
                                InkWell(
                                  key: const Key('history-clear-dates'),
                                  onTap: () => _update(
                                    (f) => f.copyWith(clearDateRange: true),
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: AppColors.textMuted,
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 20,
                                  color: AppColors.textMuted,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _SegmentedTabs(
                  selected: filters.tab,
                  onSelected: (tab) => _update((f) => f.copyWith(tab: tab)),
                ),
                const SizedBox(height: AppSpacing.sm),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _StatusChip(
                        label: 'All Status',
                        selected: filters.status == null,
                        onTap: () => _update((f) => f.copyWith(clearStatus: true)),
                      ),
                      const SizedBox(width: 6),
                      _StatusChip(
                        label: 'Status: Approved',
                        selected: filters.status == 'approved',
                        color: AppColors.success,
                        onTap: () => _update((f) => f.copyWith(status: 'approved')),
                      ),
                      const SizedBox(width: 6),
                      _StatusChip(
                        label: 'Status: Recount',
                        selected: filters.status == 'recount_requested',
                        color: AppColors.warning,
                        onTap: () => _update((f) => f.copyWith(status: 'recount_requested')),
                      ),
                      const SizedBox(width: 6),
                      _StatusChip(
                        label: 'Status: Rejected',
                        selected: filters.status == 'rejected',
                        color: AppColors.critical,
                        onTap: () => _update((f) => f.copyWith(status: 'rejected')),
                      ),
                      const SizedBox(width: 6),
                      _StatusChip(
                        label: 'Status: Pending',
                        selected: filters.status == 'pending',
                        color: AppColors.pending,
                        onTap: () => _update((f) => f.copyWith(status: 'pending')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _SummaryBar(
            total: state.loading ? null : state.total,
            isReviewer: isReviewer,
            status: filters.status,
            onClearStatus: () => _update((f) => f.copyWith(clearStatus: true)),
          ),
          Expanded(child: _buildList(state, controller, isReviewer)),
        ],
      ),
    );
  }

  Widget _buildList(
    HistoryState state,
    HistoryController controller,
    bool isReviewer,
  ) {
    if (state.loading && state.items.isEmpty) {
      return const ShimmerListPlaceholder();
    }
    if (state.error != null) {
      return ErrorState(
        message: state.error.toString(),
        isOffline: state.error.toString().toLowerCase().contains('network'),
        onRetry: controller.refresh,
      );
    }
    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 320,
              child: EmptyState(
                title: 'No history found',
                message: isReviewer
                    ? 'No stock-count or expiry-check submissions match these filters.'
                    : 'Your stock counts and expiry checks matching these filters will show up here.',
                icon: Icons.history_rounded,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.separated(
        key: const Key('history-list'),
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        itemCount: state.items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          if (index == state.items.length) {
            return _ListFooter(
              hasMore: state.hasMore,
              loadingMore: state.loadingMore,
              error: state.loadMoreError,
              onLoadMore: controller.loadMore,
            );
          }
          final obs = state.items[index];
          return HistoryRow(
            observation: obs,
            showReviewerColumns: isReviewer,
            onTap: () => context.push('/review/${obs.id}', extra: obs),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

class _FilterField extends StatelessWidget {
  const _FilterField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.xs),
        Container(
          height: 48,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _FieldText extends StatelessWidget {
  const _FieldText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.body.copyWith(fontSize: 13),
    );
  }
}

class _BranchDropdown extends StatelessWidget {
  const _BranchDropdown({
    required this.branches,
    required this.value,
    required this.allLabel,
    required this.onChanged,
  });

  final List<BranchModel> branches;
  final String? value;
  final String allLabel;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final known = branches.any((b) => b.id == value);
    return DropdownButtonHideUnderline(
      child: DropdownButton<String?>(
        key: const Key('history-branch'),
        isExpanded: true,
        value: known ? value : null,
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: AppColors.textMuted,
        ),
        style: AppTextStyles.body.copyWith(fontSize: 13),
        items: [
          DropdownMenuItem<String?>(
            value: null,
            child: Text(allLabel, overflow: TextOverflow.ellipsis),
          ),
          if (branches.length > 1)
            ...branches.map(
              (b) => DropdownMenuItem<String?>(
                value: b.id,
                child: Text(b.name, overflow: TextOverflow.ellipsis),
              ),
            ),
        ],
        onChanged: branches.length > 1 ? onChanged : null,
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({required this.selected, required this.onSelected});

  final HistoryTab selected;
  final ValueChanged<HistoryTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          for (final tab in HistoryTab.values)
            Expanded(
              child: GestureDetector(
                key: Key('history-tab-${tab.name}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelected(tab),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: tab == selected
                        ? AppColors.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border(
                      bottom: BorderSide(
                        color: tab == selected
                            ? AppColors.primaryBlue
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                  child: Text(
                    tab.label,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyStrong.copyWith(
                      fontSize: 13,
                      color: tab == selected
                          ? AppColors.primaryBlue
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({
    required this.total,
    required this.isReviewer,
    required this.status,
    required this.onClearStatus,
  });

  final int? total;
  final bool isReviewer;
  final String? status;
  final VoidCallback onClearStatus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              [
                if (total != null) '$total record${total == 1 ? '' : 's'}',
                isReviewer ? 'All staff' : 'Your submissions only',
              ].join(' · '),
              style: AppTextStyles.caption,
            ),
          ),
          if (status != null)
            InputChip(
              key: const Key('history-status-chip'),
              label: Text(historyStatuses[status] ?? status!),
              onDeleted: onClearStatus,
              deleteIcon: const Icon(Icons.close_rounded, size: 16),
              visualDensity: VisualDensity.compact,
              labelStyle: AppTextStyles.caption.copyWith(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.w700,
              ),
              backgroundColor: AppColors.infoBg,
              side: BorderSide.none,
            ),
        ],
      ),
    );
  }
}

class _StatusOption extends StatelessWidget {
  const _StatusOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label, style: AppTextStyles.bodyStrong),
      trailing: selected
          ? const Icon(Icons.check_rounded, color: AppColors.primaryBlue)
          : null,
      onTap: onTap,
    );
  }
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({
    required this.hasMore,
    required this.loadingMore,
    required this.error,
    required this.onLoadMore,
  });

  final bool hasMore;
  final bool loadingMore;
  final String? error;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (loadingMore) {
      child = const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.4),
      );
    } else if (error != null) {
      child = TextButton.icon(
        onPressed: onLoadMore,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text("Couldn't load more · Retry"),
      );
    } else if (hasMore) {
      child = TextButton(
        key: const Key('history-load-more'),
        onPressed: onLoadMore,
        child: const Text('Load more'),
      );
    } else {
      child = const Text('End of history', style: AppTextStyles.caption);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(child: child),
    );
  }
}

/// One audit row. [showReviewerColumns] adds the submitter name and the
/// signed variance; it is only ever true for Manager/Owner sessions, and the
/// Staff endpoint never returns the fields variance is derived from anyway.
class HistoryRow extends StatelessWidget {
  const HistoryRow({
    super.key,
    required this.observation,
    required this.showReviewerColumns,
    this.onTap,
  });

  final ObservationModel observation;
  final bool showReviewerColumns;
  final VoidCallback? onTap;

  static final _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');

  @override
  Widget build(BuildContext context) {
    final obs = observation;
    final isCount = obs.type == 'stock_count';
    final created = obs.createdAt?.toLocal();
    final subtitle = showReviewerColumns
        ? (obs.submittedByName ?? 'User #${obs.submittedBy ?? '-'}')
        : [
            isCount ? 'Stock Count' : 'Expiry Check',
            if (obs.batchNo != null) 'Batch ${obs.batchNo}',
          ].join(' · ');

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 8,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isCount ? AppColors.infoBg : AppColors.successBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(
              isCount ? Icons.inventory_2_outlined : Icons.event_note_outlined,
              size: 20,
              color: isCount ? AppColors.info : AppColors.success,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  obs.itemName ?? 'Item #${obs.itemId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  created != null ? _dateTimeFormat.format(created) : '-',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
                if (showReviewerColumns && obs.branchName != null)
                  Text(
                    obs.branchName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          if (showReviewerColumns) ...[
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 44,
              child: Center(
                child: VarianceIndicator(
                  key: Key('variance-${obs.id}'),
                  variance: obs.variance,
                  showArrow: false,
                  fontSize: 18,
                ),
              ),
            ),
          ],
          const SizedBox(width: AppSpacing.sm),
          StatusBadge.fromString(obs.status, compact: true),
          if (obs.status == 'recount_requested' || obs.status == 'recount') ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: () {
                final item = ItemModel(
                  id: obs.itemId,
                  name: obs.itemName ?? 'Item #${obs.itemId}',
                  sku: obs.itemCode ?? '',
                );
                if (obs.type == 'stock_count') {
                  context.push(
                    '/stock-count',
                    extra: {'item': item, 'batch': null, 'taskId': obs.taskId},
                  );
                } else {
                  context.push(
                    '/expiry-check',
                    extra: {'item': item, 'batch': null, 'taskId': obs.taskId},
                  );
                }
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.replay_rounded, color: Colors.white, size: 12),
                    SizedBox(width: 3),
                    Text(
                      'Count',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.selected,
    this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppColors.primaryBlue;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? chipColor : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? chipColor : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
