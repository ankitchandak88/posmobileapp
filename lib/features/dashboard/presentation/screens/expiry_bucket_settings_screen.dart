import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../state/dashboard_providers.dart';

/// Manager/Owner editable expiry-bucket ranges (business rule, 2026-10-10
/// client decision: these must be configurable, not hardcoded). Defaults —
/// unless an Owner/Manager has changed them — are "Expiring Soon" 0-30 days
/// (critical), "Expiring Later" 31-60 days (warning), "Watch List" 61-120
/// days (info). Validated server-side (`PUT /v1/expiry-buckets/settings`):
/// at least one bucket, the first must start at 0, no overlaps, min <= max.
class ExpiryBucketSettingsScreen extends ConsumerStatefulWidget {
  const ExpiryBucketSettingsScreen({super.key});

  @override
  ConsumerState<ExpiryBucketSettingsScreen> createState() =>
      _ExpiryBucketSettingsScreenState();
}

class _ExpiryBucketSettingsScreenState
    extends ConsumerState<ExpiryBucketSettingsScreen> {
  List<ExpiryBucketModel>? _buckets;
  bool _saving = false;
  String? _error;

  void _addBucket() {
    setState(() {
      _buckets = [
        ...(_buckets ?? []),
        ExpiryBucketModel(
          label: 'New Bucket',
          minDays: 0,
          maxDays: 0,
          severity: 'info',
          sortOrder: (_buckets?.length ?? 0) + 1,
        ),
      ];
    });
  }

  void _removeBucket(int index) {
    setState(() {
      final updated = List.of(_buckets!);
      updated.removeAt(index);
      _buckets = updated;
    });
  }

  void _updateBucket(int index, ExpiryBucketModel updated) {
    setState(() {
      final list = List.of(_buckets!);
      list[index] = updated;
      _buckets = list;
    });
  }

  Future<void> _save() async {
    if (_buckets == null || _buckets!.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await ref
          .read(expiryBucketRepositoryProvider)
          .updateSettings(_buckets!);
      ref.invalidate(expiryBucketsProvider);
      if (!mounted) return;
      setState(() => _buckets = saved);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expiry bucket settings saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = e is ApiException ? e.message : 'Could not save: $e',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bucketsAsync = ref.watch(expiryBucketsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Expiry Bucket Settings')),
      body: bucketsAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (fetched) {
          _buckets ??= fetched
              .map(
                (b) => ExpiryBucketModel(
                  id: b.id,
                  label: b.label,
                  minDays: b.minDays,
                  maxDays: b.maxDays,
                  severity: b.severity,
                  sortOrder: b.sortOrder,
                ),
              )
              .toList();

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const Text(
                'These ranges drive the expiry-exposure colours Managers/Owners '
                'see on the Dashboard. The most urgent bucket must start at day 0; '
                'buckets must not overlap each other.',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: AppSpacing.lg),
              for (var i = 0; i < _buckets!.length; i++)
                _BucketEditorCard(
                  key: ValueKey(_buckets![i].id ?? 'new-$i'),
                  bucket: _buckets![i],
                  onChanged: (updated) => _updateBucket(i, updated),
                  onRemove: () => _removeBucket(i),
                ),
              OutlinedButton.icon(
                key: const Key('expiry-bucket-add'),
                onPressed: _addBucket,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add bucket'),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error!,
                  key: const Key('expiry-bucket-error'),
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Save',
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BucketEditorCard extends StatelessWidget {
  const _BucketEditorCard({
    super.key,
    required this.bucket,
    required this.onChanged,
    required this.onRemove,
  });

  final ExpiryBucketModel bucket;
  final ValueChanged<ExpiryBucketModel> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: bucket.label,
                  decoration: const InputDecoration(labelText: 'Label'),
                  onChanged: (v) => onChanged(bucket.copyWith(label: v)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: onRemove,
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: Key('expiry-bucket-min-${bucket.id ?? bucket.label}'),
                  initialValue: bucket.minDays.toString(),
                  decoration: const InputDecoration(labelText: 'Min days'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => onChanged(
                    bucket.copyWith(minDays: int.tryParse(v) ?? 0),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextFormField(
                  key: Key('expiry-bucket-max-${bucket.id ?? bucket.label}'),
                  initialValue: bucket.maxDays.toString(),
                  decoration: const InputDecoration(labelText: 'Max days'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => onChanged(
                    bucket.copyWith(maxDays: int.tryParse(v) ?? 0),
                  ),
                ),
              ),
            ],
          ),
          DropdownButtonFormField<String>(
            key: Key('expiry-bucket-severity-${bucket.id ?? bucket.label}'),
            initialValue: bucket.severity,
            decoration: const InputDecoration(labelText: 'Severity'),
            items: const [
              DropdownMenuItem(value: 'critical', child: Text('Critical')),
              DropdownMenuItem(value: 'warning', child: Text('Warning')),
              DropdownMenuItem(value: 'info', child: Text('Info')),
            ],
            onChanged: (v) {
              if (v != null) onChanged(bucket.copyWith(severity: v));
            },
          ),
        ],
      ),
      ),
    );
  }
}
