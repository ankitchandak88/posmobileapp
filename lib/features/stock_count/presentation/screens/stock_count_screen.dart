import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../auth/state/auth_providers.dart';
import '../../../dashboard/state/dashboard_providers.dart';
import '../../../tasks/state/task_providers.dart';
import '../../state/stock_count_providers.dart';
import '../widgets/blind_batch_summary.dart';
import '../widgets/quantity_stepper.dart';

/// Blind stock-count entry screen.
/// Designed as a compact, 100% single-screen layout (zero scroll)
/// with touch-friendly controls for fast handheld scanning.
class StockCountScreen extends ConsumerStatefulWidget {
  const StockCountScreen({
    super.key,
    required this.item,
    this.batch,
    this.taskId,
  });

  final ItemModel item;
  final BatchModel? batch;
  final String? taskId;

  @override
  ConsumerState<StockCountScreen> createState() => _StockCountScreenState();
}

class _StockCountScreenState extends ConsumerState<StockCountScreen> {
  num? _physicalQty;
  final _remarksController = TextEditingController();
  final _batchController = TextEditingController();
  final _dateController = TextEditingController();
  DateTime? _expDate;
  String? _dateParseError;
  String? _photoPath;

  @override
  void initState() {
    super.initState();
    _batchController.text = widget.batch?.batchNo ?? '';
    _expDate = widget.batch?.expDate;
    if (_expDate != null) {
      _dateController.text = _formatDisplayDate(_expDate!);
    }
  }

  @override
  void dispose() {
    _batchController.dispose();
    _dateController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  String _formatDisplayDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  DateTime? _parseManualDate(String raw) {
    final clean = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length == 8) {
      // DDMMYYYY
      final day = int.tryParse(clean.substring(0, 2));
      final month = int.tryParse(clean.substring(2, 4));
      final year = int.tryParse(clean.substring(4, 8));
      if (day != null && month != null && year != null) {
        if (month >= 1 && month <= 12 && day >= 1 && day <= 31 && year >= 2020 && year <= 2045) {
          return DateTime(year, month, day);
        }
      }
    } else if (clean.length == 6) {
      // MMYYYY (last day of month)
      final month = int.tryParse(clean.substring(0, 2));
      final year = int.tryParse(clean.substring(2, 6));
      if (month != null && year != null) {
        if (month >= 1 && month <= 12 && year >= 2020 && year <= 2045) {
          final lastDay = DateTime(year, month + 1, 0).day;
          return DateTime(year, month, lastDay);
        }
      }
    }
    return null;
  }

  void _onDateTextChanged(String value) {
    final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) {
      setState(() {
        _expDate = null;
        _dateParseError = null;
      });
      return;
    }
    if (clean.length == 6 || clean.length == 8) {
      final parsed = _parseManualDate(clean);
      if (parsed != null) {
        setState(() {
          _expDate = parsed;
          _dateParseError = null;
        });
      } else {
        setState(() {
          _dateParseError = 'Invalid date. Use DDMMYYYY or MMYYYY';
        });
      }
    } else {
      setState(() {
        _dateParseError = 'Format: DDMMYYYY (e.g. 15102026) or MMYYYY';
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2045),
    );
    if (picked != null) {
      setState(() {
        _expDate = picked;
        _dateController.text = _formatDisplayDate(picked);
        _dateParseError = null;
      });
    }
  }

  void _addQty(num delta) {
    HapticFeedback.selectionClick();
    setState(() => _physicalQty = (_physicalQty ?? 0) + delta);
  }

  void _setQty(num? val) {
    HapticFeedback.selectionClick();
    setState(() => _physicalQty = val);
  }

  Future<void> _addPhoto() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (file != null) setState(() => _photoPath = file.path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera unavailable for photo capture.'),
          ),
        );
      }
    }
  }

  void _showRemarksModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            top: AppSpacing.md,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Item Remarks', style: AppTextStyles.h3),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _remarksController,
                autofocus: true,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter observation, damage notes, rack detail…',
                  hintStyle: AppTextStyles.captionMuted,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Done',
                onPressed: () {
                  setState(() {});
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_photoPath != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_photoPath!),
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: AppColors.primaryBlue),
                  title: const Text('Retake Photo'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _addPhoto();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppColors.critical),
                  title: const Text('Remove Photo', style: TextStyle(color: AppColors.critical)),
                  onTap: () {
                    setState(() => _photoPath = null);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveAndNext({required bool nextScan}) async {
    if (_physicalQty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter counted quantity before saving.'),
          backgroundColor: AppColors.critical,
        ),
      );
      return;
    }

    final rawDate = _dateController.text.trim();
    if (rawDate.isNotEmpty) {
      final parsed = _parseManualDate(rawDate);
      if (parsed != null) {
        _expDate = parsed;
      } else if (_expDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid expiry date format. Use DDMMYYYY or MMYYYY.'),
            backgroundColor: AppColors.critical,
          ),
        );
        return;
      }
    }

    final controller = ref.read(observationSubmissionProvider.notifier);
    final taskBranchId = widget.taskId != null
        ? ref.read(taskByIdProvider(widget.taskId!)).value?.branchId
        : null;
    final branches = ref.read(branchesProvider).value;
    final branchId = taskBranchId ??
        ref.read(selectedBranchIdProvider) ??
        ref.read(authControllerProvider).user?.branchId ??
        (branches != null && branches.isNotEmpty ? branches.first.id : '1');
    final batchText = _batchController.text.trim();
    final result = await controller.submit(
      type: 'stock_count',
      taskId: widget.taskId,
      itemId: widget.item.id,
      branchId: branchId,
      batchNo: batchText.isNotEmpty ? batchText : widget.batch?.batchNo,
      expDateObserved: _expDate,
      physicalQty: _physicalQty!,
      remarks: _remarksController.text.trim().isEmpty
          ? null
          : _remarksController.text.trim(),
      photoPath: _photoPath,
    );
    if (!mounted) return;
    if (result != null) {
      if (nextScan) {
        context.pushReplacement(
          '/scanner',
          extra: {'mode': 'stock_count', 'taskId': widget.taskId},
        );
      } else {
        context.pushReplacement(
          '/submission-confirmation',
          extra: {'itemName': widget.item.name, 'type': 'stock_count'},
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final submission = ref.watch(observationSubmissionProvider);
    final isSubmitting = submission.status == SubmissionStatus.submitting;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Count'),
        actions: [
          // Compact Blind Count Mode Badge
          Container(
            margin: const EdgeInsets.only(right: AppSpacing.md),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.warningBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.visibility_off_outlined,
                  color: AppColors.warning,
                  size: 13,
                ),
                SizedBox(width: 4),
                Text(
                  'Blind Count Mode',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Compact Product & Batch Card
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 10,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.item.name,
                          style: AppTextStyles.bodyStrong.copyWith(fontSize: 15),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          widget.item.sku,
                          style: AppTextStyles.barcode.copyWith(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  if (widget.batch != null) ...[
                    const SizedBox(height: 6),
                    BlindBatchSummary(batch: widget.batch),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // High-Density Quantity Stepper Card
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 12,
              ),
              child: Column(
                children: [
                  Text(
                    'Physical Quantity (Counted)',
                    style: AppTextStyles.label.copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  QuantityStepper(
                    value: _physicalQty,
                    onChanged: (v) => setState(() => _physicalQty = v),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _QuickQtyChip(label: '+1', onTap: () => _addQty(1)),
                        const SizedBox(width: 8),
                        _QuickQtyChip(
                          label: 'Reset',
                          isReset: true,
                          onTap: () => _setQty(null),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Expiry Date & Batch (Optional) Card
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.event_available_rounded,
                        size: 16,
                        color: AppColors.primaryBlue,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Batch & Expiry Date (Optional)',
                        style: AppTextStyles.label.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Batch input
                  TextField(
                    controller: _batchController,
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'Batch Number (Optional)',
                      hintText: 'e.g. A2301',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Expiry Date Manual Input with Picker suffix
                  TextField(
                    controller: _dateController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'Observed Expiry Date (Optional)',
                      hintText: 'DDMMYYYY (e.g. 15102026) or MMYYYY',
                      helperText: _expDate != null
                          ? 'Valid date: ${_formatDisplayDate(_expDate!)}'
                          : 'Format: DDMMYYYY or MMYYYY',
                      helperStyle: TextStyle(
                        color: _expDate != null ? AppColors.success : AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: _expDate != null ? FontWeight.w600 : FontWeight.normal,
                      ),
                      errorText: _dateParseError,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(
                          Icons.calendar_month_rounded,
                          color: AppColors.primaryBlue,
                        ),
                        tooltip: 'Open Calendar',
                        onPressed: _pickDate,
                      ),
                    ),
                    onChanged: _onDateTextChanged,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Remarks field button
            _CompactPillButton(
              icon: _remarksController.text.trim().isNotEmpty
                  ? Icons.check_circle_rounded
                  : Icons.edit_note_rounded,
              label: _remarksController.text.trim().isNotEmpty
                  ? 'Remarks: ${_remarksController.text.trim()}'
                  : 'Add Remarks (Optional)',
              color: _remarksController.text.trim().isNotEmpty
                  ? AppColors.primaryBlue
                  : AppColors.textSecondary,
              onTap: _showRemarksModal,
            ),
            if (submission.status == SubmissionStatus.failure) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                submission.errorMessage ??
                    'Submission failed. Please try again.',
                style: const TextStyle(color: AppColors.critical, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Button 1: Save & Next
              AppButton(
                label: 'Save & Next Scan',
                loading: isSubmitting,
                onPressed: isSubmitting
                    ? null
                    : () => _saveAndNext(nextScan: true),
              ),
              const SizedBox(height: 6),
              // Button 2: Save & Finish
              AppButton(
                label: 'Save & Finish',
                variant: AppButtonVariant.secondary,
                onPressed: isSubmitting
                    ? null
                    : () => _saveAndNext(nextScan: false),
              ),
              const SizedBox(height: 6),
              // Button 3: Add Photo Optional
              OutlinedButton.icon(
                icon: Icon(
                  _photoPath != null ? Icons.check_circle : Icons.camera_alt_outlined,
                  size: 18,
                  color: _photoPath != null ? AppColors.success : AppColors.primaryBlue,
                ),
                label: Text(
                  _photoPath != null ? 'Photo Attached (Tap to change)' : 'Add Photo (Optional)',
                  style: TextStyle(
                    fontSize: 13,
                    color: _photoPath != null ? AppColors.success : AppColors.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                  side: BorderSide(
                    color: _photoPath != null ? AppColors.success : AppColors.border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
                onPressed: _photoPath != null ? _showPhotoOptions : _addPhoto,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactPillButton extends StatelessWidget {
  const _CompactPillButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickQtyChip extends StatelessWidget {
  const _QuickQtyChip({
    required this.label,
    required this.onTap,
    this.isReset = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isReset;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isReset
                ? AppColors.surfaceAlt
                : AppColors.primaryBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isReset ? AppColors.border : AppColors.primaryBlueLight,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isReset ? AppColors.textSecondary : AppColors.primaryBlue,
            ),
          ),
        ),
      ),
    );
  }
}
