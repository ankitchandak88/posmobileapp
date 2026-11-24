import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/rider_order_model.dart';
import '../../data/vehicle_model.dart';
import '../../state/rider_order_providers.dart';

class VehicleSelectionSheet extends ConsumerStatefulWidget {
  const VehicleSelectionSheet({
    super.key,
    required this.order,
    this.stepHint,
  });

  final RiderOrderModel order;
  final String? stepHint;

  static Future<VehicleModel?> show(
    BuildContext context, {
    required RiderOrderModel order,
    String? stepHint,
  }) {
    return showModalBottomSheet<VehicleModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VehicleSelectionSheet(order: order, stepHint: stepHint),
    );
  }

  @override
  ConsumerState<VehicleSelectionSheet> createState() =>
      _VehicleSelectionSheetState();
}

class _VehicleSelectionSheetState extends ConsumerState<VehicleSelectionSheet> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(riderVehiclesProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Vehicle',
                        style: AppTextStyles.h2.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.stepHint ??
                            'Bill #${widget.order.invoiceNo} — ${widget.order.customerName}',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 12,
                          color: widget.stepHint != null
                              ? AppColors.primaryBlue
                              : null,
                          fontWeight: widget.stepHint != null
                              ? FontWeight.w600
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search vehicle number or model...',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
            ),
          ),

          // Vehicles list
          Expanded(
            child: vehiclesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 40, color: AppColors.critical),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Failed to load vehicles',
                        style: AppTextStyles.bodyStrong,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        err.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ElevatedButton(
                        onPressed: () => ref.refresh(riderVehiclesProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (vehicles) {
                final filtered = vehicles.where((v) {
                  if (_searchQuery.isEmpty) return true;
                  final reg = v.registrationNumber.toLowerCase();
                  final make = (v.make ?? '').toLowerCase();
                  final model = (v.model ?? '').toLowerCase();
                  return reg.contains(_searchQuery) ||
                      make.contains(_searchQuery) ||
                      model.contains(_searchQuery);
                }).toList()
                  ..sort((a, b) {
                    final aSel = widget.order.vehicleId == a.id ||
                        widget.order.vehicleRegistration == a.registrationNumber;
                    final bSel = widget.order.vehicleId == b.id ||
                        widget.order.vehicleRegistration == b.registrationNumber;
                    if (aSel == bSel) return 0;
                    return aSel ? -1 : 1;
                  });

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.two_wheeler_outlined,
                            size: 48,
                            color: AppColors.textSecondary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          const Text(
                            'No vehicles available',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, index) {
                    final vehicle = filtered[index];
                    final isSelected = widget.order.vehicleRegistration ==
                            vehicle.registrationNumber ||
                        widget.order.vehicleId == vehicle.id;

                    return InkWell(
                      key: Key('vehicle_option_${vehicle.id}'),
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => Navigator.of(context).pop(vehicle),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryBlue.withValues(alpha: 0.08)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primaryBlue
                                : AppColors.border,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primaryBlue
                                    : AppColors.surface,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primaryBlue
                                      : AppColors.border,
                                ),
                              ),
                              child: Icon(
                                Icons.two_wheeler_rounded,
                                size: 20,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.primaryBlue,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vehicle.registrationNumber,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: AppColors.textPrimary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    [vehicle.make, vehicle.model]
                                        .where((s) =>
                                            s != null && s.trim().isNotEmpty)
                                        .join(' • '),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.primaryBlue,
                                size: 22,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

