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
import '../../../stock_count/presentation/widgets/quantity_stepper.dart';
import '../../../stock_count/state/stock_count_providers.dart';
import '../../state/purchase_providers.dart';

/// Inward / Supplier Stock Entry Screen:
/// 1. Staff selects Supplier (searchable list)
/// 2. Staff scans product barcode or searches product
/// 3. Staff adds inward quantity + observed expiry date (+ optional batch)
/// 4. Submits for approval in Web POS (pos.indianpetcompany.com)
class InwardEntryScreen extends ConsumerStatefulWidget {
  const InwardEntryScreen({
    super.key,
    this.initialSupplier,
    this.item,
    this.batch,
  });

  final SupplierModel? initialSupplier;
  final ItemModel? item;
  final BatchModel? batch;

  @override
  ConsumerState<InwardEntryScreen> createState() => _InwardEntryScreenState();
}

class _InwardEntryScreenState extends ConsumerState<InwardEntryScreen> {
  SupplierModel? _selectedSupplier;
  ItemModel? _currentItem;
  BatchModel? _currentBatch;

  num _inwardQty = 1;
  final _batchController = TextEditingController();
  final _dateController = TextEditingController();
  final _remarksController = TextEditingController();
  DateTime? _expDate;
  String? _dateParseError;
  String? _photoPath;

  @override
  void initState() {
    super.initState();
    _selectedSupplier = widget.initialSupplier ?? ref.read(selectedSupplierProvider);
    _currentItem = widget.item;
    _currentBatch = widget.batch;

    if (_currentBatch != null) {
      _batchController.text = _currentBatch!.batchNo;
      _expDate = _currentBatch!.expDate;
      if (_expDate != null) {
        _dateController.text = _formatDisplayDate(_expDate!);
      }
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
      final day = int.tryParse(clean.substring(0, 2));
      final month = int.tryParse(clean.substring(2, 4));
      final year = int.tryParse(clean.substring(4, 8));
      if (day != null && month != null && year != null) {
        if (month >= 1 && month <= 12 && day >= 1 && day <= 31 && year >= 2020 && year <= 2045) {
          return DateTime(year, month, day);
        }
      }
    } else if (clean.length == 6) {
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
        _dateParseError = 'Format: DDMMYYYY or MMYYYY';
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
    setState(() => _inwardQty = (_inwardQty + delta) > 0 ? (_inwardQty + delta) : 1);
  }

  void _setQty(num val) {
    HapticFeedback.selectionClick();
    setState(() => _inwardQty = val > 0 ? val : 1);
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
                  Text('Inward Remarks', style: AppTextStyles.h3),
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
                  hintText: 'Invoice no, PO ref, supplier batch condition…',
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

  void _showSupplierPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _SupplierPickerSheet(
        onSelected: (supplier) {
          setState(() {
            _selectedSupplier = supplier;
          });
          ref.read(selectedSupplierProvider.notifier).state = supplier;
          Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> _scanBarcode() async {
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a supplier first.'),
          backgroundColor: AppColors.warning,
        ),
      );
      _showSupplierPicker();
      return;
    }

    final scannedItem = await context.push(
      '/scanner',
      extra: {'mode': 'inward', 'supplier': _selectedSupplier},
    );

    if (scannedItem != null && scannedItem is ItemModel) {
      setState(() {
        _currentItem = scannedItem;
        _inwardQty = 1;
        _batchController.clear();
        _dateController.clear();
        _expDate = null;
        _dateParseError = null;
      });
    }
  }

  Future<void> _searchProduct() async {
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a supplier first.'),
          backgroundColor: AppColors.warning,
        ),
      );
      _showSupplierPicker();
      return;
    }

    final selectedItem = await context.push(
      '/product-search',
      extra: {'mode': 'inward', 'supplier': _selectedSupplier},
    );

    if (selectedItem != null && selectedItem is ItemModel) {
      setState(() {
        _currentItem = selectedItem;
        _inwardQty = 1;
        _batchController.clear();
        _dateController.clear();
        _expDate = null;
        _dateParseError = null;
      });
    }
  }

  Future<void> _submitInward({required bool nextItem}) async {
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a supplier.'),
          backgroundColor: AppColors.critical,
        ),
      );
      _showSupplierPicker();
      return;
    }

    if (_currentItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please scan or select a product.'),
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
    final branches = ref.read(branchesProvider).value;
    final branchId = ref.read(selectedBranchIdProvider) ??
        ref.read(authControllerProvider).user?.branchId ??
        (branches != null && branches.isNotEmpty ? branches.first.id : '1');
    final batchText = _batchController.text.trim();

    final result = await controller.submit(
      type: 'stock_count',
      itemId: _currentItem!.id,
      branchId: branchId,
      supplierId: _selectedSupplier!.id,
      batchNo: batchText.isNotEmpty ? batchText : _currentBatch?.batchNo,
      expDateObserved: _expDate,
      physicalQty: _inwardQty,
      remarks: _remarksController.text.trim().isEmpty
          ? null
          : _remarksController.text.trim(),
      photoPath: _photoPath,
    );

    if (!mounted) return;
    if (result != null) {
      if (nextItem) {
        setState(() {
          _currentItem = null;
          _currentBatch = null;
          _inwardQty = 1;
          _batchController.clear();
          _dateController.clear();
          _remarksController.clear();
          _expDate = null;
          _photoPath = null;
          _dateParseError = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item submitted for approval! Scan next item.'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        context.pushReplacement(
          '/submission-confirmation',
          extra: {
            'itemName': _currentItem!.name,
            'type': 'inward',
          },
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
        title: const Text('Inward / Supplier Stock'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: AppSpacing.md),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.successBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_outlined,
                  color: AppColors.success,
                  size: 13,
                ),
                SizedBox(width: 4),
                Text(
                  'Web Approval Mode',
                  style: TextStyle(
                    color: AppColors.success,
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
            // STEP 1: Supplier Selector Card
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.local_shipping_rounded,
                            size: 16,
                            color: AppColors.primaryBlue,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Step 1: Supplier / Vendor',
                            style: AppTextStyles.label.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                      if (_selectedSupplier != null)
                        TextButton(
                          onPressed: _showSupplierPicker,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(50, 24),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Change', style: TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_selectedSupplier == null)
                    InkWell(
                      onTap: _showSupplierPicker,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          border: Border.all(color: AppColors.primaryBlueLight),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search, size: 18, color: AppColors.primaryBlue),
                            SizedBox(width: 8),
                            Text(
                              'Tap to Select Supplier (Required)',
                              style: TextStyle(
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.business_rounded,
                            color: AppColors.primaryBlue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedSupplier!.name,
                                style: AppTextStyles.bodyStrong.copyWith(fontSize: 15),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_selectedSupplier!.mobile != null || _selectedSupplier!.phone != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  _selectedSupplier!.mobile ?? _selectedSupplier!.phone ?? '',
                                  style: AppTextStyles.captionMuted.copyWith(fontSize: 11),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // STEP 2: Product Barcode Scan / Lookup
            if (_currentItem == null)
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    const Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 40,
                      color: AppColors.primaryBlue,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Step 2: Scan Product Barcode',
                      style: AppTextStyles.h3.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Scan product or search item to add inward quantity and expiry date.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: 'Scan Product Barcode',
                      icon: Icons.qr_code_scanner,
                      onPressed: _scanBarcode,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: 'Search Product Manually',
                      variant: AppButtonVariant.secondary,
                      icon: Icons.search,
                      onPressed: _searchProduct,
                    ),
                  ],
                ),
              )
            else ...[
              // Product Card
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentItem!.name,
                            style: AppTextStyles.bodyStrong.copyWith(fontSize: 15),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'SKU: ${_currentItem!.sku} · MRP: ₹${_currentItem!.mrp ?? '-'}',
                            style: AppTextStyles.captionMuted.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _currentItem = null),
                      child: const Text('Change', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Inward Quantity Stepper Card
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    Text(
                      'Inward Quantity (Stock Arrived)',
                      style: AppTextStyles.label.copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    QuantityStepper(
                      value: _inwardQty,
                      onChanged: (v) => setState(() => _inwardQty = (v != null && v > 0) ? v : 1),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _QuickQtyChip(label: '+1', onTap: () => _addQty(1)),
                          const SizedBox(width: 8),
                          _QuickQtyChip(label: '+5', onTap: () => _addQty(5)),
                          const SizedBox(width: 8),
                          _QuickQtyChip(label: '+10', onTap: () => _addQty(10)),
                          const SizedBox(width: 8),
                          _QuickQtyChip(
                            label: 'Reset',
                            isReset: true,
                            onTap: () => _setQty(1),
                          ),
                        ],
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
            ],

            if (submission.status == SubmissionStatus.failure) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                submission.errorMessage ?? 'Submission failed. Please try again.',
                style: const TextStyle(color: AppColors.critical, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: _currentItem == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Button 1: Save & Next Item
                    AppButton(
                      label: 'Save & Next Item',
                      loading: isSubmitting,
                      onPressed: isSubmitting
                          ? null
                          : () => _submitInward(nextItem: true),
                    ),
                    const SizedBox(height: 6),
                    // Button 2: Save & Finish
                    AppButton(
                      label: 'Save & Finish (Submit to POS)',
                      variant: AppButtonVariant.secondary,
                      onPressed: isSubmitting
                          ? null
                          : () => _submitInward(nextItem: false),
                    ),
                    const SizedBox(height: 6),
                    // Button 3: Add Photo
                    OutlinedButton.icon(
                      icon: Icon(
                        _photoPath != null ? Icons.check_circle : Icons.camera_alt_outlined,
                        size: 18,
                        color: _photoPath != null ? AppColors.success : AppColors.primaryBlue,
                      ),
                      label: Text(
                        _photoPath != null ? 'Photo Attached' : 'Add Photo (Optional)',
                        style: TextStyle(
                          fontSize: 13,
                          color: _photoPath != null ? AppColors.success : AppColors.primaryBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(40),
                        side: BorderSide(
                          color: _photoPath != null ? AppColors.success : AppColors.border,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                      ),
                      onPressed: _addPhoto,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SupplierPickerSheet extends ConsumerStatefulWidget {
  const _SupplierPickerSheet({required this.onSelected});

  final ValueChanged<SupplierModel> onSelected;

  @override
  ConsumerState<_SupplierPickerSheet> createState() => _SupplierPickerSheetState();
}

class _SupplierPickerSheetState extends ConsumerState<_SupplierPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          top: AppSpacing.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Select Supplier', style: AppTextStyles.h2),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search supplier name or phone…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                ),
                onChanged: (val) => setState(() => _query = val.trim().toLowerCase()),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: suppliersAsync.when(
                  data: (suppliers) {
                    final filtered = _query.isEmpty
                        ? suppliers
                        : suppliers.where((s) {
                            return s.name.toLowerCase().contains(_query) ||
                                (s.mobile != null && s.mobile!.contains(_query)) ||
                                (s.phone != null && s.phone!.contains(_query));
                          }).toList();

                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text(
                          'No suppliers found matching search.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final s = filtered[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                            child: const Icon(Icons.local_shipping_outlined, color: AppColors.primaryBlue, size: 20),
                          ),
                          title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: (s.mobile != null || s.phone != null)
                              ? Text(s.mobile ?? s.phone ?? '', style: const TextStyle(fontSize: 12))
                              : null,
                          onTap: () => widget.onSelected(s),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text('Failed to load suppliers: $e', style: const TextStyle(color: AppColors.critical)),
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
