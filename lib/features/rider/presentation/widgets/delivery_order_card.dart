import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../data/rider_order_model.dart';
import '../../services/navigation_service.dart';
import 'km_input_dialog.dart';
import 'vehicle_selection_sheet.dart';

class DeliveryOrderCard extends StatelessWidget {
  const DeliveryOrderCard({
    super.key,
    required this.order,
    required this.onStartDelivery,
    required this.onMarkDelivered,
    this.onAssignVehicle,
  });

  final RiderOrderModel order;
  final Future<void> Function(int orderId, double startingKm) onStartDelivery;
  final Future<void> Function(int orderId, double endingKm, [String? notes]) onMarkDelivered;
  final Future<bool> Function(int orderId, int vehicleId, String regNo)? onAssignVehicle;

  Color _statusColor() {
    switch (order.status) {
      case 'assigned':
      case 'pending':
        return AppColors.warning;
      case 'out_for_delivery':
        return AppColors.primaryBlue;
      case 'delivered':
      case 'completed':
        return AppColors.success;
      case 'rescheduled':
        return Colors.purple;
      case 'cancelled':
        return AppColors.critical;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Invoice No + Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      size: 16,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Bill #${order.invoiceNo}',
                    style: AppTextStyles.h3.copyWith(fontSize: 15),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  order.statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.sm),

          // Customer info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.person_outline_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.customerName,
                      style: AppTextStyles.bodyStrong.copyWith(fontSize: 15),
                    ),
                    if (order.customerPhone.isNotEmpty)
                      Text(
                        order.customerPhone,
                        style: AppTextStyles.caption.copyWith(fontSize: 13),
                      ),
                  ],
                ),
              ),
              // Total Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${order.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: order.isPaidOnline
                          ? AppColors.successBg
                          : AppColors.warningBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      order.isPaidOnline ? 'PAID ONLINE' : 'CASH TO COLLECT',
                      style: TextStyle(
                        color: order.isPaidOnline
                            ? AppColors.success
                            : AppColors.warning,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Address
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: AppColors.primaryBlue,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    order.fullAddress,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Vehicle Info & Selection Option (shown before KM)
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: order.vehicleRegistration != null
                  ? AppColors.primaryBlue.withValues(alpha: 0.06)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: order.vehicleRegistration != null
                    ? AppColors.primaryBlue.withValues(alpha: 0.3)
                    : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.two_wheeler_rounded,
                      size: 16,
                      color: order.vehicleRegistration != null
                          ? AppColors.primaryBlue
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      order.vehicleRegistration != null
                          ? 'Vehicle: ${order.vehicleRegistration}'
                          : 'No vehicle assigned',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: order.vehicleRegistration != null
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: order.vehicleRegistration != null
                            ? AppColors.primaryBlue
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (onAssignVehicle != null && !order.isDelivered)
                  InkWell(
                    key: Key('assign_vehicle_btn_${order.id}'),
                    onTap: () async {
                      final selected = await VehicleSelectionSheet.show(
                        context,
                        order: order,
                      );
                      if (selected != null) {
                        await onAssignVehicle!(
                          order.id,
                          selected.id,
                          selected.registrationNumber,
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        order.vehicleRegistration != null ? 'Change' : '+ Select',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // KM Info if active
          if (order.startingKm != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 2,
              children: [
                const Icon(Icons.speed, size: 14, color: AppColors.textSecondary),
                Text(
                  'Start: ${order.startingKm!} km',
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
                if (order.endingKm != null) ...[
                  const Text('•', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                  Text(
                    'End: ${order.endingKm!} km',
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                  ),
                ],
                if (order.kmTravelled != null) ...[
                  const Text('•', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                  Text(
                    'Travelled: ${order.kmTravelled!} km',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ],
            ),
          ],

          if ((order.deliveryNote != null && order.deliveryNote!.trim().isNotEmpty) ||
              (order.notes != null && order.notes!.trim().isNotEmpty)) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.note_alt_outlined, size: 14, color: AppColors.primaryBlue),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Delivery Note: ${(order.deliveryNote ?? order.notes)!.trim()}',
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 11,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.md),

          // One-tap Action Buttons Row: Call, Google Maps, WhatsApp
          Row(
            children: [
              // Call
              Expanded(
                child: OutlinedButton.icon(
                  key: Key('call_button_${order.id}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.success,
                    side: const BorderSide(color: AppColors.success),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.call_rounded, size: 16),
                  label: const Text('Call', style: TextStyle(fontSize: 12)),
                  onPressed: order.customerPhone.isNotEmpty
                      ? () => NavigationService.callCustomer(order.customerPhone)
                      : null,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),

              // Google Maps
              Expanded(
                child: ElevatedButton.icon(
                  key: Key('maps_button_${order.id}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.map_rounded, size: 16),
                  label: const Text('Map', style: TextStyle(fontSize: 12)),
                  onPressed: () => NavigationService.openGoogleMaps(
                    googleMapLink: order.googleMapLink,
                    address: order.fullAddress,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),

              // WhatsApp
              SizedBox(
                width: 44,
                child: OutlinedButton(
                  key: Key('whatsapp_button_${order.id}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.teal,
                    side: const BorderSide(color: Colors.teal),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: order.customerPhone.isNotEmpty
                      ? () => NavigationService.openWhatsApp(
                            order.customerPhone,
                            defaultMessage:
                                'Hello ${order.customerName}, this is Urban Pets delivery regarding your order #${order.invoiceNo}.',
                          )
                      : null,
                  child: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                ),
              ),
            ],
          ),

          // Primary Delivery Progression Action (Start Delivery / Mark Delivered)
          if (order.isAssigned) ...[
            const SizedBox(height: AppSpacing.sm),
            ElevatedButton.icon(
              key: Key('start_delivery_button_${order.id}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.two_wheeler_rounded, size: 18),
              label: const Text(
                'Start Delivery (Vehicle & KM)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              onPressed: () async {
                final selectedVehicle = await VehicleSelectionSheet.show(
                  context,
                  order: order,
                  stepHint: 'Step 1 of 2 • Select Vehicle (Next: Starting KM)',
                );
                if (selectedVehicle == null || !context.mounted) return;

                if (onAssignVehicle != null &&
                    selectedVehicle.id != order.vehicleId) {
                  final assigned = await onAssignVehicle!(
                    order.id,
                    selectedVehicle.id,
                    selectedVehicle.registrationNumber,
                  );
                  if (!assigned || !context.mounted) return;
                }

                final orderWithVehicle = order.copyWith(
                  vehicleId: selectedVehicle.id,
                  vehicleRegistration: selectedVehicle.registrationNumber,
                );

                final km = await KmInputDialog.show(
                  context,
                  order: orderWithVehicle,
                  isStartingKm: true,
                );
                if (km != null) {
                  await onStartDelivery(order.id, km);
                }
              },
            ),
          ] else if (order.isOutForDelivery) ...[
            const SizedBox(height: AppSpacing.sm),
            ElevatedButton.icon(
              key: Key('mark_delivered_button_${order.id}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: const Text(
                'Mark Delivered (Enter Ending KM)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              onPressed: () async {
                final result = await KmInputDialog.show(
                  context,
                  order: order,
                  isStartingKm: false,
                );
                if (result is DeliveryCompletionResult) {
                  await onMarkDelivered(order.id, result.km, result.notes);
                } else if (result is double) {
                  await onMarkDelivered(order.id, result, null);
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}
