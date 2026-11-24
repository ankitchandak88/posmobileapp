import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../dashboard/state/dashboard_providers.dart';
import '../../data/purchase_lookup_model.dart';
import '../../state/purchase_providers.dart';

class PurchaseLookupScreen extends ConsumerStatefulWidget {
  const PurchaseLookupScreen({super.key, this.initialCode});

  final String? initialCode;

  @override
  ConsumerState<PurchaseLookupScreen> createState() => _PurchaseLookupScreenState();
}

class _PurchaseLookupScreenState extends ConsumerState<PurchaseLookupScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialCode ?? '');
    if (widget.initialCode != null && widget.initialCode!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performLookup(widget.initialCode!.trim());
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performLookup(String code) {
    final branchId = ref.read(selectedBranchIdProvider);
    ref.read(purchaseLookupProvider.notifier).lookup(code, branchId: branchId);
  }

  Future<void> _scanBarcode() async {
    final scanned = await context.push<String>('/scanner', extra: {'mode': 'purchase'});
    if (scanned != null && scanned.trim().isNotEmpty) {
      _searchController.text = scanned.trim();
      _performLookup(scanned.trim());
    }
  }

  Future<void> _callSupplier(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(purchaseLookupProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Purchase & Rate Lookup'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Scan Barcode',
            onPressed: _scanBarcode,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search Input Row with embedded scan button
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.cardShadow,
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Enter or scan Barcode / SKU / Item ID…',
                        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        prefixIcon: Icon(Icons.search, size: 20, color: AppColors.textMuted),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      onSubmitted: (val) => _performLookup(val),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primaryBlue),
                    tooltip: 'Scan Barcode',
                    onPressed: _scanBarcode,
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => _performLookup(_searchController.text),
                      child: const Text('Lookup', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            if (state.isLoading) ...[
              const SizedBox(height: 60),
              const Center(child: CircularProgressIndicator()),
            ] else if (state.errorMessage != null) ...[
              AppCard(
                color: AppColors.criticalBg,
                child: Column(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.critical, size: 36),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      state.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.critical, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton(
                      onPressed: () => _performLookup(_searchController.text),
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            ] else if (state.data != null) ...[
              _buildProductContent(state.data!),
            ] else ...[
              const SizedBox(height: 80),
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.document_scanner_outlined,
                        size: 48,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'Scan Barcode to Check Purchase Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Instant view of Purchase Price, Margin, Primary Supplier, and Inward History.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                      label: const Text('Open Barcode Scanner'),
                      onPressed: _scanBarcode,
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

  Widget _buildProductContent(PurchaseLookupModel data) {
    final item = data.item;
    final pricing = data.pricing;
    final supplier = data.supplier;
    final inventory = data.inventory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Product Basic Info Card
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: AppTextStyles.h3.copyWith(color: AppColors.navy),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text('SKU: ${item.sku}', style: AppTextStyles.caption),
                            ),
                            if (item.barcode != null && item.barcode!.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.infoBg,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('EAN: ${item.barcode}', style: AppTextStyles.caption.copyWith(color: AppColors.info)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (item.brandName != null || item.categoryName != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (item.brandName != null)
                      Text('Brand: ${item.brandName}', style: AppTextStyles.captionMuted),
                    if (item.brandName != null && item.categoryName != null)
                      const Text('·', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    if (item.categoryName != null)
                      Text('Category: ${item.categoryName}', style: AppTextStyles.captionMuted),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Purchase Pricing & Margin Matrix
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Purchase & Margin Details', style: AppTextStyles.label),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: pricing.marginPercent > 0 ? AppColors.successBg : AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${pricing.marginPercent}% Margin',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: pricing.marginPercent > 0 ? AppColors.success : AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _PriceStat(
                      label: 'Purchase Cost',
                      value: '₹${pricing.costPrice.toStringAsFixed(2)}',
                      color: AppColors.primaryBlue,
                      highlight: true,
                    ),
                  ),
                  Expanded(
                    child: _PriceStat(
                      label: 'Landing Cost',
                      value: '₹${pricing.landingCost.toStringAsFixed(2)}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _PriceStat(
                      label: 'MRP',
                      value: '₹${pricing.mrp.toStringAsFixed(2)}',
                    ),
                  ),
                  Expanded(
                    child: _PriceStat(
                      label: 'Sell Price',
                      value: '₹${pricing.sellPrice.toStringAsFixed(2)}',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Primary Supplier & Current Stock
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Supplier
            Expanded(
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Primary Supplier', style: AppTextStyles.label.copyWith(fontSize: 11)),
                    const SizedBox(height: 6),
                    Text(
                      supplier?.name ?? 'No Primary Supplier',
                      style: AppTextStyles.bodyStrong.copyWith(fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (supplier?.mobile != null && supplier!.mobile!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => _callSupplier(supplier.mobile!),
                        child: Row(
                          children: [
                            const Icon(Icons.phone_outlined, size: 13, color: AppColors.primaryBlue),
                            const SizedBox(width: 4),
                            Text(
                              supplier.mobile!,
                              style: const TextStyle(fontSize: 11, color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (supplier?.gstin != null && supplier!.gstin!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('GST: ${supplier.gstin}', style: AppTextStyles.caption.copyWith(fontSize: 10)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Current Stock
            Expanded(
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current Stock', style: AppTextStyles.label.copyWith(fontSize: 11)),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          inventory.currentStock % 1 == 0
                              ? inventory.currentStock.toInt().toString()
                              : inventory.currentStock.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text('Units', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${inventory.batchCount} active batch${inventory.batchCount == 1 ? '' : 'es'}',
                      style: AppTextStyles.caption.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // Recent Inward / Purchase History
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent Inward History', style: AppTextStyles.label),
                  Text('${data.recentInwards.length} records', style: AppTextStyles.caption),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (data.recentInwards.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'No recent purchase invoices found for this item.',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ),
                )
              else
                ...data.recentInwards.map((line) => _InwardHistoryRow(line: line)),
            ],
          ),
        ),
      ],
    );
  }
}

class _PriceStat extends StatelessWidget {
  const _PriceStat({
    required this.label,
    required this.value,
    this.color,
    this.highlight = false,
  });

  final String label;
  final String value;
  final Color? color;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: highlight
            ? (color ?? AppColors.primaryBlue).withValues(alpha: 0.08)
            : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight
              ? (color ?? AppColors.primaryBlue).withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption.copyWith(fontSize: 10)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InwardHistoryRow extends StatelessWidget {
  const _InwardHistoryRow({required this.line});

  final PurchaseInwardLine line;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.receipt_long_rounded, size: 16, color: AppColors.primaryBlue),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Inv #${line.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text('₹${line.costPrice.toStringAsFixed(2)} / unit', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.primaryBlue)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${line.supplierName} · Qty: ${line.qty}${line.freeQty > 0 ? " + Free: ${line.freeQty}" : ""}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                if (line.invoiceDate != null || line.batchNo != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (line.invoiceDate != null)
                        Text(line.invoiceDate!, style: AppTextStyles.caption.copyWith(fontSize: 10)),
                      if (line.batchNo != null) ...[
                        const Text(' · ', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                        Text('Batch: ${line.batchNo}', style: AppTextStyles.caption.copyWith(fontSize: 10)),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
