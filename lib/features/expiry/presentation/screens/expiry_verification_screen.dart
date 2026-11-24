import 'dart:io';

import 'package:flutter/material.dart';
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
import '../../../stock_count/state/stock_count_providers.dart';

/// Expiry verification entry: optional batch, manual date (DDMMYYYY or MMYYYY) or picker, optional photo evidence.
/// Styled in high-density single-screen handheld layout matching StockCountScreen.
class ExpiryVerificationScreen extends ConsumerStatefulWidget {
  const ExpiryVerificationScreen({
    super.key,
    required this.item,
    this.batch,
    this.taskId,
  });

  final ItemModel item;
  final BatchModel? batch;
  final String? taskId;

  @override
  ConsumerState<ExpiryVerificationScreen> createState() =>
      _ExpiryVerificationScreenState();
}

class _ExpiryVerificationScreenState
    extends ConsumerState<ExpiryVerificationScreen> {
  final _batchController = TextEditingController();
  final _dateController = TextEditingController();
  final _remarksController = TextEditingController();
  DateTime? _expDate;
  String? _photoPath;
  String? _dateParseError;

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
                  Text('Expiry Remarks', style: AppTextStyles.h3),
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
                  hintText: 'Enter observation, sticker condition, supplier batch…',
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
    // If text was entered but not parsed yet:
    if (_expDate == null && _dateController.text.trim().isNotEmpty) {
      final parsed = _parseManualDate(_dateController.text.trim());
      if (parsed != null) {
        _expDate = parsed;
      }
    }

    if (_expDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Observed expiry date is required (format DDMMYYYY or MMYYYY).'),
          backgroundColor: AppColors.critical,
        ),
      );
      return;
    }

    final taskBranchId = widget.taskId != null
        ? ref.read(taskByIdProvider(widget.taskId!)).value?.branchId
        : null;
    final branches = ref.read(branchesProvider).value;
    final branchId = taskBranchId ??
        ref.read(selectedBranchIdProvider) ??
        ref.read(authControllerProvider).user?.branchId ??
        (branches != null && branches.isNotEmpty ? branches.first.id : '1');

    final batchText = _batchController.text.trim();
    final result = await ref
        .read(observationSubmissionProvider.notifier)
        .submit(
          type: 'expiry_check',
          taskId: widget.taskId,
          itemId: widget.item.id,
          branchId: branchId,
          batchNo: batchText.isEmpty ? null : batchText,
          expDateObserved: _expDate,
          remarks: _remarksController.text.trim().isEmpty
              ? null
              : _remarksController.text.trim(),
          photoPath: _photoPath,
        );

    if (!mounted) return;
    if (result != null) {
      if (nextScan) {
        if (context.canPop()) {
          context.pop(true);
        } else {
          context.pushReplacement(
            '/scanner',
            extra: {'mode': 'expiry_check', 'taskId': widget.taskId},
          );
        }
      } else {
        context.pushReplacement(
          '/submission-confirmation',
          extra: {'itemName': widget.item.name, 'type': 'expiry_check'},
        );
      }
    } else {
      final errorMsg = ref.read(observationSubmissionProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg ?? 'Failed to save expiry verification. Please try again.'),
          backgroundColor: AppColors.critical,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final submission = ref.watch(observationSubmissionProvider);
    final isSubmitting = submission.status == SubmissionStatus.submitting;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expiry Verification'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Compact Product Card
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 10,
              ),
              child: Row(
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
            ),
            const SizedBox(height: AppSpacing.sm),

            // Batch & Expiry Card
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Batch & Expiry Date',
                    style: AppTextStyles.label.copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  // Batch input (NOT COMPULSORY / OPTIONAL)
                  TextField(
                    controller: _batchController,
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'Batch Number (Optional)',
                      hintText: 'e.g. A2301 (Optional)',
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
                  const SizedBox(height: AppSpacing.md),

                  // Observed Expiry Date Manual Input with Picker suffix
                  TextField(
                    controller: _dateController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'Observed Expiry Date',
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
                label: 'Save & Next',
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
                    fontWeight: FontWeight.w600,
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
