import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../auth/state/auth_providers.dart';
import '../../../history/state/history_providers.dart';
import '../../data/observation_repository.dart';
import '../../state/review_providers.dart';

/// Observation detail with Approve / Request Recount / Reject actions.
///
/// Reached from the manager review queue AND from History & Audit (by every
/// role). It is therefore role-aware: the system-quantity comparison and the
/// review actions render only for Manager/Owner. For Staff the server never
/// sends system_qty_snapshot in the first place (blind counting, master
/// prompt §6) — hiding the card is defence in depth, not the control.
class ObservationDetailScreen extends ConsumerStatefulWidget {
  const ObservationDetailScreen({super.key, required this.observation});

  final ObservationModel observation;

  @override
  ConsumerState<ObservationDetailScreen> createState() =>
      _ObservationDetailScreenState();
}

class _ObservationDetailScreenState
    extends ConsumerState<ObservationDetailScreen> {
  final _remarksController = TextEditingController();

  /// Enriched detail (recounts chain + parent) fetched on open. Starts as
  /// the row model the screen was opened with so the UI paints immediately;
  /// recount history and the photo-evidence card only need the richer
  /// `show()` response, which list endpoints never embed.
  late ObservationModel _detail;

  /// Approved TARGET quantity sent as `approved_qty` (the server computes the
  /// actual adjustment from current stock). Pre-filled with the staff count;
  /// left EMPTY when there is no count (e.g. an expiry check without a
  /// quantity) so a manager can never approve an accidental "0" — previously
  /// this defaulted to 0, which would have posted a correction setting the
  /// item's stock to zero.
  late final TextEditingController _approvedQtyController;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _detail = widget.observation;
    final qty = widget.observation.physicalQty;
    _approvedQtyController = TextEditingController(
      text: qty == null ? '' : (qty % 1 == 0 ? qty.toInt().toString() : '$qty'),
    );
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final full = await ref
          .read(observationRepositoryProvider)
          .show(widget.observation.id);
      if (mounted) {
        setState(() {
          if (widget.observation.itemId == '-') {
            _detail = full;
          } else {
            _detail = ObservationModel(
              id: widget.observation.id,
              type: widget.observation.type,
              taskId: widget.observation.taskId,
              itemId: widget.observation.itemId,
              itemName: widget.observation.itemName,
              branchId: widget.observation.branchId,
              branchName: widget.observation.branchName,
              batchNo: widget.observation.batchNo,
              expDateObserved: widget.observation.expDateObserved,
              physicalQty: widget.observation.physicalQty,
              remarks: widget.observation.remarks,
              photoPath: full.photoPath ?? widget.observation.photoPath,
              idempotencyKey: widget.observation.idempotencyKey,
              systemQtySnapshot: widget.observation.systemQtySnapshot,
              status: widget.observation.status,
              parentObservationId: widget.observation.parentObservationId,
              approvedQty: widget.observation.approvedQty,
              actualAdjustmentQty: widget.observation.actualAdjustmentQty,
              reviewRemarks: widget.observation.reviewRemarks,
              submittedBy: widget.observation.submittedBy,
              submittedByName: widget.observation.submittedByName,
              reviewedBy: widget.observation.reviewedBy,
              reviewedByName: widget.observation.reviewedByName,
              createdAt: widget.observation.createdAt,
              itemCode: widget.observation.itemCode,
              reviewedAt: widget.observation.reviewedAt,
              recounts: full.recounts.isNotEmpty
                  ? full.recounts
                  : widget.observation.recounts,
              parentObservation: full.parentObservation ??
                  widget.observation.parentObservation,
            );
          }
        });
      }
    } catch (_) {
      // Keep showing the row model we already have — recount history and
      // the photo card just stay absent, same as any other "not loaded yet".
    }
  }

  @override
  void dispose() {
    _remarksController.dispose();
    _approvedQtyController.dispose();
    super.dispose();
  }

  num? get _approvedQty {
    final parsed = num.tryParse(_approvedQtyController.text.trim());
    return (parsed == null || parsed < 0) ? null : parsed;
  }

  Future<void> _act(Future<void> Function() action) async {
    setState(() => _acting = true);
    try {
      await action();
      ref.invalidate(pendingReviewProvider);
      ref.invalidate(historyControllerProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  void _shareDiscrepancy(ObservationModel obs) {
    HapticFeedback.lightImpact();
    final item = obs.itemName ?? 'Item #${obs.itemId}';
    final sku = obs.itemCode ?? '-';
    final type = obs.type == 'stock_count' ? 'Stock Count' : 'Expiry Check';
    final varianceStr = obs.variance != null
        ? (obs.variance! > 0
            ? '+${obs.variance} (Overage)'
            : '${obs.variance} (Shortage)')
        : 'N/A';
    final text = '''
📦 Urban Pets — Audit Discrepancy Report
• Type: $type
• Item: $item
• SKU: $sku
• Status: ${obs.status.toUpperCase()}
• System Qty: ${obs.systemQtySnapshot ?? '-'}
• Physical Count: ${obs.physicalQty ?? '-'}
• Variance: $varianceStr
• Submitted by: ${obs.submittedByName ?? '-'}
• Batch: ${obs.batchNo ?? '-'}
• Date: ${obs.createdAt != null ? '${obs.createdAt!.day}/${obs.createdAt!.month}/${obs.createdAt!.year}' : '-'}
''';
    Clipboard.setData(ClipboardData(text: text.trim()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Discrepancy report copied to clipboard! Ready to share.'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final obs = _detail;
    final repo = ref.read(observationRepositoryProvider);
    final isReviewer =
        ref.watch(authControllerProvider).user?.isManagerOrOwner ?? false;
    final canAct = isReviewer && obs.status == 'pending';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Observation Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share discrepancy summary',
            onPressed: () => _shareDiscrepancy(obs),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          obs.itemName ?? 'Item #${obs.itemId}',
                          style: AppTextStyles.h3,
                        ),
                      ),
                      StatusBadge.fromString(obs.status),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _row(
                    'Type',
                    obs.type == 'stock_count' ? 'Stock Count' : 'Expiry Check',
                  ),
                  _row('Branch', obs.branchName ?? obs.branchId),
                  _row('Batch', obs.batchNo ?? '-'),
                  if (obs.submittedByName != null || obs.submittedBy != null)
                    _row(
                      'Submitted by',
                      obs.submittedByName ?? obs.submittedBy!,
                    ),
                  if (obs.expDateObserved != null)
                    _row(
                      'Observed expiry',
                      '${obs.expDateObserved!.day}/${obs.expDateObserved!.month}/${obs.expDateObserved!.year}',
                    ),
                  if (obs.reviewedByName != null)
                    _row('Reviewed by', obs.reviewedByName!),
                  if (obs.reviewRemarks != null)
                    _row('Review remarks', obs.reviewRemarks!),
                  if (obs.remarks != null) _row('Staff remarks', obs.remarks!),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (!isReviewer)
              AppCard(
                child: _QtyStat(
                  label: 'Your count',
                  value: obs.physicalQty?.toString() ?? '-',
                ),
              )
            else
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quantity Comparison', style: AppTextStyles.label),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: _QtyStat(
                            label: 'System Qty',
                            value: obs.systemQtySnapshot?.toString() ?? '-',
                          ),
                        ),
                        Expanded(
                          child: _QtyStat(
                            label: 'Physical Qty',
                            value: obs.physicalQty?.toString() ?? '-',
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Variance', style: AppTextStyles.caption),
                              const SizedBox(height: 4),
                              VarianceIndicator(variance: obs.variance),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (isReviewer && _detail.photoPath != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _PhotoEvidenceCard(observationId: _detail.id, repo: repo),
            ],
            if (_detail.recounts.isNotEmpty || _detail.parentObservation != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recount History', style: AppTextStyles.label),
                    const SizedBox(height: AppSpacing.md),
                    if (_detail.parentObservation != null)
                      _recountRow('Original attempt', _detail.parentObservation!),
                    for (final r in _detail.recounts) _recountRow('Recount', r),
                  ],
                ),
              ),
            ],
            if (canAct) ...[
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Review Remarks',
                controller: _remarksController,
                hintText: 'Optional for approve, required for recount/reject',
                maxLines: 3,
                // Rebuild so Request Recount / Reject enable as soon as a
                // remark is typed (they were previously stuck disabled —
                // nothing triggered a rebuild on text change).
                onChanged: (_) => setState(() {}),
              ),
              // An expiry_check approval never changes stock (business rule,
              // 2026-10-10) — the server doesn't even accept approved_qty for
              // this type, so a quantity field here would be meaningless and
              // would wrongly block approval of an expiry check that was
              // never counted in the first place.
              if (obs.type == 'stock_count') ...[
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  key: const Key('approved-qty-field'),
                  label: 'Approved target quantity',
                  controller: _approvedQtyController,
                  hintText: obs.physicalQty == null
                      ? 'Enter the verified quantity to approve'
                      : null,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Approve',
                loading: _acting,
                icon: Icons.check_circle_outline,
                onPressed:
                    _acting ||
                        (obs.type == 'stock_count' && _approvedQty == null)
                    ? null
                    : () => _act(
                        () => repo.approve(
                          obs.id,
                          approvedQty: obs.type == 'stock_count'
                              ? _approvedQty!
                              : null,
                          remarks: _remarksController.text.trim().isEmpty
                              ? null
                              : _remarksController.text.trim(),
                        ),
                      ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Request Recount',
                variant: AppButtonVariant.secondary,
                loading: _acting,
                icon: Icons.replay_circle_filled_outlined,
                onPressed: _acting || _remarksController.text.trim().isEmpty
                    ? null
                    : () => _act(
                        () => repo.requestRecount(
                          obs.id,
                          remarks: _remarksController.text.trim(),
                        ),
                      ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Reject',
                variant: AppButtonVariant.danger,
                loading: _acting,
                icon: Icons.cancel_outlined,
                onPressed: _acting || _remarksController.text.trim().isEmpty
                    ? null
                    : () => _act(
                        () => repo.reject(
                          obs.id,
                          remarks: _remarksController.text.trim(),
                        ),
                      ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  'Remarks are required for Request Recount and Reject.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
            ],
            if (obs.status == 'recount_requested') ...[
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                color: AppColors.warning.withValues(alpha: 0.08),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Recount Requested',
                          style: AppTextStyles.h3.copyWith(color: AppColors.warning),
                        ),
                      ],
                    ),
                    if (obs.reviewRemarks != null && obs.reviewRemarks!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Reason: ${obs.reviewRemarks}',
                        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: obs.type == 'stock_count' ? 'Count Stock Now' : 'Verify Expiry Now',
                      icon: obs.type == 'stock_count' ? Icons.inventory_2_rounded : Icons.event_busy_rounded,
                      onPressed: () {
                        final item = ItemModel(
                          id: obs.itemId,
                          name: obs.itemName ?? 'Item #${obs.itemId}',
                          sku: obs.itemCode ?? '',
                        );
                        final batch = obs.batchNo != null && obs.batchNo!.isNotEmpty
                            ? BatchModel(batchNo: obs.batchNo!, expDate: obs.expDateObserved)
                            : null;
                        if (obs.type == 'stock_count') {
                          context.push(
                            '/stock-count',
                            extra: {'item': item, 'batch': batch, 'taskId': obs.taskId},
                          );
                        } else {
                          context.push(
                            '/expiry-check',
                            extra: {'item': item, 'batch': batch, 'taskId': obs.taskId},
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _recountRow(String label, ObservationModel o) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              '$label · ${o.physicalQty?.toString() ?? '-'}'
              '${o.reviewRemarks != null ? ' — ${o.reviewRemarks}' : ''}',
              style: AppTextStyles.body,
            ),
          ),
          StatusBadge.fromString(o.status),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.caption),
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

/// Fetches and renders the authorised evidence photo for an observation
/// (`GET /v1/observations/{id}/photo`, Manager/Owner only). Only built when
/// the caller is a reviewer AND the observation actually has a photo — see
/// the gate in [ObservationDetailScreen.build].
class _PhotoEvidenceCard extends StatefulWidget {
  const _PhotoEvidenceCard({required this.observationId, required this.repo});

  final String observationId;
  final ObservationRepository repo;

  @override
  State<_PhotoEvidenceCard> createState() => _PhotoEvidenceCardState();
}

class _PhotoEvidenceCardState extends State<_PhotoEvidenceCard> {
  late Future<List<int>> _photo;

  @override
  void initState() {
    super.initState();
    _photo = widget.repo.photoBytes(widget.observationId);
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Evidence Photo', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.md),
          FutureBuilder<List<int>>(
            future: _photo,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return const Text(
                  'Could not load the photo.',
                  style: TextStyle(color: AppColors.textMuted),
                );
              }
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  Uint8List.fromList(snapshot.data!),
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox(
                    height: 160,
                    child: Center(
                      child: Text(
                        'Could not load the photo.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QtyStat extends StatelessWidget {
  const _QtyStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
