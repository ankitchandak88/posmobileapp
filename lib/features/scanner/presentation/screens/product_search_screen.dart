import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../state/scanner_providers.dart';

class ProductSearchScreen extends ConsumerStatefulWidget {
  const ProductSearchScreen({super.key, required this.mode, this.taskId});

  final String mode;
  final String? taskId;

  @override
  ConsumerState<ProductSearchScreen> createState() =>
      _ProductSearchScreenState();
}

class _ProductSearchScreenState extends ConsumerState<ProductSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        ref.read(itemSearchQueryProvider.notifier).state = value;
      }
    });
  }

  void _clearSearch() {
    _controller.clear();
    _debounceTimer?.cancel();
    ref.read(itemSearchQueryProvider.notifier).state = '';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(itemSearchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Search'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.search,
                    color: AppColors.textMuted,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Search Name, Barcode, MRP or SKU…',
                        hintStyle: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  if (_controller.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(
                        Icons.clear_rounded,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                      onPressed: _clearSearch,
                    ),
                  IconButton(
                    tooltip: 'Scan Barcode',
                    icon: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: AppColors.primaryBlue,
                      size: 20,
                    ),
                    onPressed: () => context.push(
                      '/scanner',
                      extra: {'mode': widget.mode, 'taskId': widget.taskId},
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: resultsAsync.when(
              data: (items) {
                if (ref.watch(itemSearchQueryProvider).trim().length < 2) {
                  return const EmptyState(
                    title: 'Search for a product',
                    message:
                        'Type at least 2 characters to search by name, SKU, or barcode.',
                    icon: Icons.search,
                  );
                }
                if (items.isEmpty) {
                  return const EmptyState(
                    title: 'No products found',
                    message:
                        'Try a different search term, or scan the barcode instead.',
                    icon: Icons.search_off,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 10,
                      ),
                      onTap: () {
                        if (widget.mode == 'inward') {
                          if (context.canPop()) {
                            context.pop(item);
                          } else {
                            context.pushReplacement(
                              '/inward-entry',
                              extra: {'item': item},
                            );
                          }
                        } else if (widget.mode == 'expiry_check') {
                          context.push(
                            '/expiry-check',
                            extra: {
                              'item': item,
                              'batch': null,
                              'taskId': widget.taskId,
                            },
                          );
                        } else if (widget.mode == 'view') {
                          context.push(
                            '/quick-item-view',
                            extra: {
                              'item': item,
                              'taskId': widget.taskId,
                            },
                          );
                        } else {
                          context.push(
                            '/stock-count',
                            extra: {
                              'item': item,
                              'batch': null,
                              'taskId': widget.taskId,
                            },
                          );
                        }
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.inventory_2_outlined,
                              color: AppColors.primaryBlue,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: AppTextStyles.bodyStrong.copyWith(fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceAlt,
                                        borderRadius: BorderRadius.circular(3),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Text(
                                        item.sku,
                                        style: AppTextStyles.barcode.copyWith(fontSize: 10),
                                      ),
                                    ),
                                    if (item.barcode != null && item.barcode!.isNotEmpty) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        '· ${item.barcode}',
                                        style: AppTextStyles.caption.copyWith(fontSize: 11),
                                      ),
                                    ],
                                    if (item.mrp != null) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.successBg,
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: Text(
                                          'MRP: ₹${item.mrp}',
                                          style: const TextStyle(
                                            color: AppColors.success,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (item.categoryName != null) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        item.categoryName!,
                                        style: AppTextStyles.caption.copyWith(fontSize: 11),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textMuted,
                            size: 18,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const LoadingState(),
              error: (e, _) => ErrorState(message: e.toString()),
            ),
          ),
        ],
      ),
    );
  }
}
