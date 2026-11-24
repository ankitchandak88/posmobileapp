import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../auth/state/auth_providers.dart';
import '../../../dashboard/state/dashboard_providers.dart';
import '../../../scanner/state/scanner_providers.dart';
import '../../state/task_providers.dart';

/// A product picked for a task, optionally pinned to one of its batches.
typedef SelectedTaskItem = ({ItemModel item, String? batchNo});

/// Manager/Owner "Assign Task" screen (master prompt §9): branch, section /
/// rack, product **category or brand**, optional selected products (picked
/// from the category/brand-filtered product list), assignee, due date and
/// priority. Submits `POST /v1/tasks`; the server re-validates permission,
/// branch access, assignee branch access and that every selected product
/// is inside the chosen category/brand.
class CreateTaskScreen extends ConsumerStatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  ConsumerState<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends ConsumerState<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _sectionController = TextEditingController();

  String? _branchId;
  // Business rule (2026-10-10): multiple categories/brands are allowed only
  // when explicitly selected — these are plain multi-select lists; a single
  // selection is just a one-element list, sent to the server the same way.
  List<String> _categoryValueIds = [];
  List<String> _brandIds = [];
  List<String> _assigneeIds = [];
  DateTime? _dueDate;
  String _priority = 'normal';
  final Map<String, SelectedTaskItem> _selectedItems = {};
  bool _submitting = false;
  String? _error;

  static final _dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _branchId = ref.read(authControllerProvider).user?.branchId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _sectionController.dispose();
    super.dispose();
  }

  /// The product picker/scope-count query only supports a single
  /// category/brand filter server-side ([ItemController::search]); when more
  /// than one is selected we show products matching the FIRST of each as a
  /// representative preview — full union enforcement always happens
  /// server-side on submit regardless of what the picker displays.
  ({String? categoryValueId, String? brandId, String query}) get _scope => (
    categoryValueId: _categoryValueIds.isEmpty ? null : _categoryValueIds.first,
    brandId: _brandIds.isEmpty ? null : _brandIds.first,
    query: '',
  );

  /// Keeps already-picked products consistent with a changed scope — the
  /// server would reject them (422) anyway; dropping them here avoids a
  /// confusing round-trip. A product is kept if it matches ANY selected
  /// category OR ANY selected brand (union), matching the server's rule.
  void _pruneSelectionToScope() {
    if (_categoryValueIds.isEmpty && _brandIds.isEmpty) return;
    _selectedItems.removeWhere((_, selection) {
      final inCategory = _categoryValueIds.contains(
        selection.item.categoryValueId,
      );
      final inBrand = _brandIds.contains(selection.item.brandId);
      return !inCategory && !inBrand;
    });
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _pickProducts() async {
    final result = await showModalBottomSheet<Map<String, SelectedTaskItem>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.85,
        child: ProductPickerSheet(
          categoryValueId: _scope.categoryValueId,
          brandId: _scope.brandId,
          branchId: _branchId,
          initialSelection: Map.of(_selectedItems),
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _selectedItems
          ..clear()
          ..addAll(result);
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_branchId == null) {
      setState(() => _error = 'Select a branch.');
      return;
    }
    if (_assigneeIds.isEmpty) {
      setState(() => _error = 'Select who this task is assigned to.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref
          .read(taskRepositoryProvider)
          .create(
            branchId: _branchId!,
            title: _titleController.text.trim(),
            section: _sectionController.text.trim().isEmpty
                ? null
                : _sectionController.text.trim(),
            categoryValueIds: _categoryValueIds,
            brandIds: _brandIds,
            assignedTo: _assigneeIds.first,
            assignedToIds: _assigneeIds,
            dueDate: _dueDate,
            priority: _priority,
            items: [
              for (final entry in _selectedItems.entries)
                (itemId: entry.key, batchNo: entry.value.batchNo),
            ],
          );
      ref.invalidate(myTasksProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Task assigned.')));
      if (context.canPop()) context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = e is ApiException ? e.message : 'Could not assign: $e',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final branchesAsync = ref.watch(branchesProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final brandsAsync = ref.watch(brandsByScopeProvider(
      _categoryValueIds.isNotEmpty ? _categoryValueIds.first : null,
    ));
    final hasScope = _categoryValueIds.isNotEmpty || _brandIds.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Assign Task')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _Section(
              title: 'Where',
              children: [
                _LabeledDropdown<BranchModel>(
                  fieldKey: const Key('create-task-branch'),
                  label: 'Branch',
                  async: branchesAsync,
                  value: _branchId,
                  hint: 'Select branch',
                  options: (branches) => [
                    for (final b in branches) (value: b.id, label: b.name),
                  ],
                  onChanged: (v) => setState(() {
                    _branchId = v;
                    _assigneeIds = []; // assignee list is branch-specific
                  }),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Section / Rack (optional)',
                  controller: _sectionController,
                  hintText: 'e.g. Dog Food - Rack A',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _Section(
              title: 'What to count',
              subtitle:
                  'Scope the task by product category or brand (or both).',
              children: [
                _MultiSelectField<CategoryModel>(
                  fieldKey: const Key('create-task-category'),
                  label: 'Category (select one or more)',
                  async: categoriesAsync,
                  values: _categoryValueIds,
                  hint: 'Any category',
                  options: (categories) => [
                    for (final c in categories) (value: c.id, label: c.name),
                  ],
                  onChanged: (v) => setState(() {
                    _categoryValueIds = v;
                    _pruneSelectionToScope();
                  }),
                ),
                const SizedBox(height: AppSpacing.md),
                _MultiSelectField<BrandModel>(
                  fieldKey: const Key('create-task-brand'),
                  label: 'Brand (select one or more)',
                  async: brandsAsync,
                  values: _brandIds,
                  hint: 'Any brand',
                  options: (brands) => [
                    for (final b in brands) (value: b.id, label: b.name),
                  ],
                  onChanged: (v) => setState(() {
                    _brandIds = v;
                    _pruneSelectionToScope();
                  }),
                ),
                if (hasScope) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Consumer(
                    builder: (context, ref, _) {
                      final scopeAsync = ref.watch(scopeItemsProvider(_scope));
                      return Text(
                        scopeAsync.when(
                          data: (page) =>
                              '${page.total} product${page.total == 1 ? '' : 's'} in this scope',
                          loading: () => 'Counting products in scope…',
                          error: (e, _) => 'Could not load products: $e',
                        ),
                        key: const Key('create-task-scope-count'),
                        style: AppTextStyles.caption,
                      );
                    },
                  ),
                ],
                if (_categoryValueIds.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Consumer(
                    builder: (context, ref, _) {
                      final scopeAsync = ref.watch(scopeItemsProvider(_scope));
                      return scopeAsync.when(
                        data: (page) {
                          if (page.items.isEmpty) return const SizedBox.shrink();
                          return Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(horizontal: 10),
                              collapsedBackgroundColor: AppColors.surfaceAlt,
                              backgroundColor: AppColors.surfaceAlt,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                side: const BorderSide(color: AppColors.border),
                              ),
                              collapsedShape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                side: const BorderSide(color: AppColors.border),
                              ),
                              title: Text(
                                'Products in category (${page.total})',
                                style: AppTextStyles.bodyStrong.copyWith(fontSize: 12),
                              ),
                              subtitle: const Text(
                                'Tap to view products with count & expiry options',
                                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                              children: [
                                const Divider(height: 1, color: AppColors.border),
                                for (int idx = 0; idx < (page.items.length > 5 ? 5 : page.items.length); idx++) ...[
                                  ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                    title: Text(
                                      '${idx + 1}. ${page.items[idx].name}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text(page.items[idx].sku, style: AppTextStyles.caption.copyWith(fontSize: 10)),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          onTap: () => context.push(
                                            '/stock-count',
                                            extra: {'item': page.items[idx], 'batch': null},
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryBlue.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'Count',
                                              style: TextStyle(
                                                color: AppColors.primaryBlue,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        InkWell(
                                          onTap: () => context.push(
                                            '/expiry-check',
                                            extra: {'item': page.items[idx], 'batch': null},
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppColors.successBg,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'Expiry',
                                              style: TextStyle(
                                                color: AppColors.success,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (idx < (page.items.length > 5 ? 5 : page.items.length) - 1)
                                    const Divider(height: 1, color: AppColors.border),
                                ],
                              ],
                            ),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (e, _) => const SizedBox.shrink(),
                      );
                    },
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  key: const Key('create-task-pick-products'),
                  onPressed: _pickProducts,
                  icon: const Icon(Icons.playlist_add_check_rounded),
                  label: Text(
                    _selectedItems.isEmpty
                        ? (hasScope
                              ? 'Pick specific products (optional)'
                              : 'Select products (optional)')
                        : '${_selectedItems.length} product${_selectedItems.length == 1 ? '' : 's'} selected',
                  ),
                ),
                if (_selectedItems.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final entry in _selectedItems.entries)
                        InputChip(
                          label: Text(
                            entry.value.batchNo == null
                                ? entry.value.item.name
                                : '${entry.value.item.name} · batch ${entry.value.batchNo}',
                          ),
                          onDeleted: () =>
                              setState(() => _selectedItems.remove(entry.key)),
                        ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _Section(
              title: 'Who & when',
              children: [
                AppTextField(
                  label: 'Task title',
                  controller: _titleController,
                  hintText: 'e.g. Count Royal Canin dog food',
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Title is required'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                if (_branchId == null)
                  const Text(
                    'Select a branch to choose an assignee.',
                    style: AppTextStyles.caption,
                  )
                else
                  _MultiSelectField<AssigneeModel>(
                    fieldKey: const Key('create-task-assignee'),
                    label: 'Assign to (select one or more staff)',
                    async: ref.watch(assigneesProvider(_branchId!)),
                    values: _assigneeIds,
                    hint: 'Select staff member(s)',
                    options: (users) => [
                      for (final u in users)
                        (
                          value: u.id,
                          label: u.role == null
                              ? u.name
                              : '${u.name} (${u.role})',
                        ),
                    ],
                    onChanged: (v) => setState(() => _assigneeIds = v),
                  ),
                const SizedBox(height: AppSpacing.md),
                Text('Due date (optional)', style: AppTextStyles.label),
                const SizedBox(height: AppSpacing.xs),
                InkWell(
                  onTap: _pickDueDate,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.event_outlined,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _dueDate == null
                                ? 'No due date'
                                : _dateFormat.format(_dueDate!),
                            style: AppTextStyles.body,
                          ),
                        ),
                        if (_dueDate != null)
                          InkWell(
                            onTap: () => setState(() => _dueDate = null),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Priority', style: AppTextStyles.label),
                const SizedBox(height: AppSpacing.xs),
                SegmentedButton<String>(
                  key: const Key('create-task-priority'),
                  segments: const [
                    ButtonSegment(value: 'low', label: Text('Low')),
                    ButtonSegment(value: 'normal', label: Text('Normal')),
                    ButtonSegment(value: 'high', label: Text('High')),
                  ],
                  selected: {_priority},
                  onSelectionChanged: (s) =>
                      setState(() => _priority = s.first),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                key: const Key('create-task-error'),
                style: const TextStyle(color: AppColors.critical, fontSize: 13),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Assign Task',
              icon: Icons.assignment_turned_in_outlined,
              loading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, this.subtitle, required this.children});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTextStyles.h3),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: AppTextStyles.caption),
          ],
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

/// Dropdown bound to an [AsyncValue] list — loading/error states inline.
class _LabeledDropdown<T> extends StatelessWidget {
  const _LabeledDropdown({
    required this.fieldKey,
    required this.label,
    required this.async,
    required this.value,
    required this.hint,
    required this.options,
    required this.onChanged,
    this.allowClear = false,
  });

  final Key fieldKey;
  final String label;
  final AsyncValue<List<T>> async;
  final String? value;
  final String hint;
  final List<({String value, String label})> Function(List<T>) options;
  final ValueChanged<String?> onChanged;
  final bool allowClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: fieldKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.xs),
        async.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (e, _) => Text(
            'Could not load ${label.toLowerCase()}: $e',
            style: const TextStyle(color: AppColors.critical, fontSize: 12),
          ),
          data: (list) {
            final opts = options(list);
            final known = opts.any((o) => o.value == value);
            // Keyed by the controlled value so the field re-syncs when the
            // parent resets it (e.g. assignee cleared after a branch change).
            return DropdownButtonFormField<String?>(
              key: ValueKey('$fieldKey|${known ? value : ''}'),
              initialValue: known ? value : null,
              isExpanded: true,
              hint: Text(hint),
              items: [
                if (allowClear)
                  DropdownMenuItem<String?>(value: null, child: Text(hint)),
                for (final o in opts)
                  DropdownMenuItem<String?>(
                    value: o.value,
                    child: Text(o.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: onChanged,
            );
          },
        ),
      ],
    );
  }
}

/// Multi-select field (business rule 2026-10-10: a task may be scoped to
/// more than one category/brand, but only when explicitly chosen). Shows
/// the current selection as removable chips and opens a checkbox dialog to
/// change it.
class _MultiSelectField<T> extends StatelessWidget {
  const _MultiSelectField({
    required this.fieldKey,
    required this.label,
    required this.async,
    required this.values,
    required this.hint,
    required this.options,
    required this.onChanged,
  });

  final Key fieldKey;
  final String label;
  final AsyncValue<List<T>> async;
  final List<String> values;
  final String hint;
  final List<({String value, String label})> Function(List<T>) options;
  final ValueChanged<List<String>> onChanged;

  Future<void> _openPicker(
    BuildContext context,
    List<({String value, String label})> opts,
  ) async {
    final selected = Set<String>.of(values);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(label),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final o in opts)
                  CheckboxListTile(
                    key: Key('${fieldKey.toString()}-option-${o.value}'),
                    value: selected.contains(o.value),
                    title: Text(o.label),
                    onChanged: (checked) => setDialogState(() {
                      if (checked ?? false) {
                        selected.add(o.value);
                      } else {
                        selected.remove(o.value);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(<String>{}),
              child: const Text('Clear'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(selected),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
    if (result != null) onChanged(result.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: fieldKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: AppSpacing.xs),
        async.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (e, _) => Text(
            'Could not load ${label.toLowerCase()}: $e',
            style: const TextStyle(color: AppColors.critical, fontSize: 12),
          ),
          data: (list) {
            final opts = options(list);
            final selectedLabels = [
              for (final o in opts)
                if (values.contains(o.value)) o.label,
            ];
            return InkWell(
              onTap: () => _openPicker(context, opts),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedLabels.isEmpty
                            ? hint
                            : selectedLabels.join(', '),
                        style: AppTextStyles.body,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_drop_down_rounded,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Multi-select product picker over `GET /v1/items/search`, pre-filtered by
/// the task's category/brand so only in-scope products can be picked.
class ProductPickerSheet extends ConsumerStatefulWidget {
  const ProductPickerSheet({
    super.key,
    this.categoryValueId,
    this.brandId,
    this.branchId,
    this.initialSelection = const {},
  });

  final String? categoryValueId;
  final String? brandId;

  /// Needed to look up per-item batches (stock is branch-scoped). Batch
  /// selection is skipped if null (e.g. no branch chosen yet).
  final String? branchId;
  final Map<String, SelectedTaskItem> initialSelection;

  @override
  ConsumerState<ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends ConsumerState<ProductPickerSheet> {
  final _queryController = TextEditingController();
  String _query = '';
  late final Map<String, SelectedTaskItem> _selected = Map.of(
    widget.initialSelection,
  );

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  bool get _hasScope =>
      widget.categoryValueId != null || widget.brandId != null;

  @override
  Widget build(BuildContext context) {
    // Without a category/brand scope, require at least 2 characters before
    // searching so we never page through the whole catalogue by accident.
    final canSearch = _hasScope || _query.trim().length >= 2;
    final resultsAsync = canSearch
        ? ref.watch(
            scopeItemsProvider((
              categoryValueId: widget.categoryValueId,
              brandId: widget.brandId,
              query: _query,
            )),
          )
        : null;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _hasScope ? 'Products in this scope' : 'Search products',
            style: AppTextStyles.h3,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const Key('product-picker-search'),
            controller: _queryController,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Name, code or barcode',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onSubmitted: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: resultsAsync == null
                ? const EmptyState(
                    title: 'Search for products',
                    message:
                        'Type at least 2 characters, or choose a category/brand first.',
                    icon: Icons.search_rounded,
                  )
                : resultsAsync.when(
                    loading: () => const LoadingState(),
                    error: (e, _) => ErrorState(message: e.toString()),
                    data: (page) {
                      if (page.items.isEmpty) {
                        return const EmptyState(
                          title: 'No products found',
                          icon: Icons.inventory_2_outlined,
                        );
                      }
                      return ListView(
                        children: [
                          for (final item in page.items) ...[
                            CheckboxListTile(
                              key: Key('product-picker-item-${item.id}'),
                              value: _selected.containsKey(item.id),
                              title: Text(item.name),
                              subtitle: Text(
                                item.sku.isEmpty ? '-' : item.sku,
                                style: AppTextStyles.caption,
                              ),
                              onChanged: (checked) => setState(() {
                                if (checked ?? false) {
                                  _selected[item.id] = (
                                    item: item,
                                    batchNo: null,
                                  );
                                } else {
                                  _selected.remove(item.id);
                                }
                              }),
                            ),
                            if (_selected.containsKey(item.id) &&
                                widget.branchId != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: AppSpacing.xxl,
                                  right: AppSpacing.lg,
                                  bottom: AppSpacing.sm,
                                ),
                                child: _BatchPicker(
                                  itemId: item.id,
                                  branchId: widget.branchId!,
                                  selectedBatchNo: _selected[item.id]!.batchNo,
                                  onChanged: (batchNo) => setState(() {
                                    _selected[item.id] = (
                                      item: item,
                                      batchNo: batchNo,
                                    );
                                  }),
                                ),
                              ),
                          ],
                          if (page.hasMore)
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Text(
                                'Showing ${page.items.length} of ${page.total}. Refine the search to find more.',
                                style: AppTextStyles.caption,
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: AppButton(
                label: _selected.isEmpty
                    ? 'Done'
                    : 'Use ${_selected.length} product${_selected.length == 1 ? '' : 's'}',
                onPressed: () => Navigator.of(context).pop(_selected),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Optional "pin to a specific batch" control shown under a checked product
/// in [ProductPickerSheet]. Most tasks leave this unset (count every batch);
/// the server accepts `items[].batch_no` for the cases that need one.
class _BatchPicker extends ConsumerWidget {
  const _BatchPicker({
    required this.itemId,
    required this.branchId,
    required this.selectedBatchNo,
    required this.onChanged,
  });

  final String itemId;
  final String branchId;
  final String? selectedBatchNo;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batchesAsync = ref.watch(
      itemBatchesProvider((itemId: itemId, branchId: branchId)),
    );

    return batchesAsync.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (_, _) => const SizedBox.shrink(),
      data: (batches) {
        if (batches.isEmpty) return const SizedBox.shrink();
        return DropdownButtonFormField<String?>(
          key: Key('product-picker-batch-$itemId'),
          initialValue: selectedBatchNo,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Specific batch (optional)',
            isDense: true,
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Any batch'),
            ),
            for (final b in batches)
              DropdownMenuItem<String?>(value: b.batchNo, child: Text(b.batchNo)),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}
