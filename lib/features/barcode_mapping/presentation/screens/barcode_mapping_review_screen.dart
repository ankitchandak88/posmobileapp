import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../scanner/state/scanner_providers.dart';
import '../../data/barcode_mapping_repository.dart';
import 'barcode_mapping_screen.dart' show barcodeMappingRepositoryProvider;

/// Pending unknown-barcode mapping requests for the Manager/Owner's
/// branch(es) — `GET /v1/barcode-mapping-requests?status=pending`.
final pendingMappingRequestsProvider =
    FutureProvider.autoDispose<PagedResult<BarcodeMappingRequestModel>>((
      ref,
    ) async {
      return ref.read(barcodeMappingRepositoryProvider).list();
    });

/// Manager/Owner review of unknown-barcode mapping requests (master prompt
/// §9 "Mapping requests require authorized review", screen 15).
///
/// Safety rules mirrored from the server: nothing changes master data until
/// a reviewer approves; approving onto a product that already has a
/// DIFFERENT barcode requires a second, explicit "Replace" confirmation
/// (sent as `force: true` only after it); reject requires a reason.
class BarcodeMappingReviewScreen extends ConsumerWidget {
  const BarcodeMappingReviewScreen({super.key});

  static final _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

  Future<void> _approve(
    BuildContext context,
    WidgetRef ref,
    BarcodeMappingRequestModel request,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    var itemId = request.suggestedItemId;
    var itemName = request.suggestedItemName;

    if (itemId == null) {
      final picked = await showDialog<ItemModel>(
        context: context,
        builder: (_) => const _PickItemDialog(),
      );
      if (picked == null) return;
      itemId = picked.id;
      itemName = picked.name;
    }
    if (!context.mounted) return;

    final confirmed = await _confirm(
      context,
      title: 'Approve mapping?',
      message:
          'Barcode ${request.scannedBarcode} will be assigned to "$itemName".',
      action: 'Approve',
    );
    if (!confirmed) return;

    final repo = ref.read(barcodeMappingRepositoryProvider);
    try {
      await repo.approve(request.id, itemId: itemId);
    } on ApiException catch (e) {
      final needsForce =
          e.statusCode == 422 && e.message.contains('already mapped');
      if (!needsForce || !context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
        return;
      }
      final replace = await _confirm(
        context,
        title: 'Replace existing barcode?',
        message: e.message.replaceAll(' Pass force=true to overwrite.', ''),
        action: 'Replace',
        destructive: true,
      );
      if (!replace) return;
      try {
        await repo.approve(request.id, itemId: itemId, force: true);
      } on ApiException catch (e2) {
        messenger.showSnackBar(SnackBar(content: Text(e2.message)));
        return;
      }
    }
    messenger.showSnackBar(const SnackBar(content: Text('Mapping approved.')));
    ref.invalidate(pendingMappingRequestsProvider);
  }

  Future<void> _reject(
    BuildContext context,
    WidgetRef ref,
    BarcodeMappingRequestModel request,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final remarks = await showDialog<String>(
      context: context,
      builder: (_) => const _RejectDialog(),
    );
    if (remarks == null) return;
    try {
      await ref
          .read(barcodeMappingRepositoryProvider)
          .reject(request.id, remarks: remarks);
      messenger.showSnackBar(
        const SnackBar(content: Text('Mapping request rejected.')),
      );
      ref.invalidate(pendingMappingRequestsProvider);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: destructive
                ? TextButton.styleFrom(foregroundColor: AppColors.critical)
                : null,
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(pendingMappingRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Barcode Requests')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(pendingMappingRequestsProvider),
        child: requestsAsync.when(
          loading: () => const LoadingState(),
          error: (e, _) => ErrorState(
            message: e.toString(),
            onRetry: () => ref.invalidate(pendingMappingRequestsProvider),
          ),
          data: (page) {
            if (page.items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(
                    height: 360,
                    child: EmptyState(
                      title: 'No pending barcode requests',
                      message:
                          'Unknown barcodes reported by staff will appear here for review.',
                      icon: Icons.qr_code_2_rounded,
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: page.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final r = page.items[index];
                final replaces =
                    r.suggestedItemCurrentBarcode != null &&
                    r.suggestedItemCurrentBarcode!.trim().isNotEmpty &&
                    r.suggestedItemCurrentBarcode!.trim() !=
                        r.scannedBarcode.trim();
                return AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.qr_code_2_rounded,
                            color: AppColors.primaryBlue,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              r.scannedBarcode,
                              style: AppTextStyles.h3.copyWith(
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          StatusBadge.fromString(r.status),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        r.suggestedItemName != null
                            ? 'Suggested product: ${r.suggestedItemName}'
                            : 'No product suggested — you will pick one.',
                        style: AppTextStyles.bodyStrong,
                      ),
                      if (replaces)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Currently mapped to ${r.suggestedItemCurrentBarcode} — approving will ask before replacing it.',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        [
                          if (r.branchName != null) r.branchName!,
                          if (r.submittedByName != null)
                            'by ${r.submittedByName}',
                          if (r.createdAt != null)
                            _dateFormat.format(r.createdAt!.toLocal()),
                        ].join(' · '),
                        style: AppTextStyles.caption,
                      ),
                      if (r.remarks != null && r.remarks!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            '"${r.remarks}"',
                            style: AppTextStyles.caption,
                          ),
                        ),
                      if (r.status == 'pending') ...[
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                key: Key('mapping-reject-${r.id}'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.critical,
                                  side: const BorderSide(
                                    color: AppColors.critical,
                                  ),
                                ),
                                onPressed: () => _reject(context, ref, r),
                                child: const Text('Reject'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: ElevatedButton(
                                key: Key('mapping-approve-${r.id}'),
                                onPressed: () => _approve(context, ref, r),
                                child: const Text('Approve'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text.trim();
    return AlertDialog(
      title: const Text('Reject request'),
      content: TextField(
        key: const Key('mapping-reject-remarks'),
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        decoration: const InputDecoration(hintText: 'Reason (required)'),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: text.isEmpty
              ? null
              : () => Navigator.of(context).pop(text),
          style: TextButton.styleFrom(foregroundColor: AppColors.critical),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}

/// Lets the reviewer choose the product when the staff member suggested none.
class _PickItemDialog extends ConsumerStatefulWidget {
  const _PickItemDialog();

  @override
  ConsumerState<_PickItemDialog> createState() => _PickItemDialogState();
}

class _PickItemDialogState extends ConsumerState<_PickItemDialog> {
  final _controller = TextEditingController();
  Future<List<ItemModel>>? _results;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search() {
    final q = _controller.text.trim();
    if (q.length < 2) return;
    setState(() => _results = ref.read(itemRepositoryProvider).search(q));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choose product'),
      content: SizedBox(
        width: double.maxFinite,
        height: 360,
        child: Column(
          children: [
            TextField(
              key: const Key('mapping-item-search'),
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Name or code',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search_rounded),
                  onPressed: _search,
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: _results == null
                  ? const Center(
                      child: Text(
                        'Search at least 2 characters.',
                        style: AppTextStyles.caption,
                      ),
                    )
                  : FutureBuilder<List<ItemModel>>(
                      future: _results,
                      builder: (context, snap) {
                        if (snap.connectionState != ConnectionState.done) {
                          return const LoadingState();
                        }
                        if (snap.hasError) {
                          return Text(
                            snap.error.toString(),
                            style: const TextStyle(color: AppColors.critical),
                          );
                        }
                        final items = snap.data ?? const [];
                        if (items.isEmpty) {
                          return const Center(
                            child: Text(
                              'No products found.',
                              style: AppTextStyles.caption,
                            ),
                          );
                        }
                        return ListView(
                          children: [
                            for (final item in items)
                              ListTile(
                                title: Text(item.name),
                                subtitle: Text(
                                  [
                                    item.sku,
                                    if (item.barcode != null &&
                                        item.barcode!.isNotEmpty)
                                      'current barcode ${item.barcode}',
                                  ].join(' · '),
                                ),
                                onTap: () => Navigator.of(context).pop(item),
                              ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
