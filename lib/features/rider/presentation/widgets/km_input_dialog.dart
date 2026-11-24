import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/rider_order_model.dart';

class DeliveryCompletionResult {
  const DeliveryCompletionResult({
    required this.km,
    this.notes,
  });

  final double km;
  final String? notes;
}

class KmInputDialog extends StatefulWidget {
  const KmInputDialog({
    super.key,
    required this.order,
    required this.isStartingKm,
  });

  final RiderOrderModel order;
  final bool isStartingKm;

  static Future<dynamic> show(
    BuildContext context, {
    required RiderOrderModel order,
    required bool isStartingKm,
  }) {
    return showDialog<dynamic>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => KmInputDialog(
        order: order,
        isStartingKm: isStartingKm,
      ),
    );
  }

  @override
  State<KmInputDialog> createState() => _KmInputDialogState();
}

class _KmInputDialogState extends State<KmInputDialog> {
  final _controller = TextEditingController();
  final _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _customError;

  @override
  void dispose() {
    _controller.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _customError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final entered = double.tryParse(_controller.text.trim());
    if (entered == null || entered <= 0) {
      setState(() => _customError = 'Please enter a valid positive KM reading');
      return;
    }

    if (!widget.isStartingKm && widget.order.startingKm != null) {
      if (entered <= widget.order.startingKm!) {
        setState(() => _customError =
            'Ending KM must be greater than starting KM (${widget.order.startingKm!} km)');
        return;
      }
    }

    if (!widget.isStartingKm) {
      final noteText = _notesController.text.trim();
      Navigator.of(context).pop(DeliveryCompletionResult(
        km: entered,
        notes: noteText.isNotEmpty ? noteText : null,
      ));
    } else {
      Navigator.of(context).pop(entered);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isStartingKm
        ? 'Start Delivery — Odometer'
        : 'Complete Delivery — Odometer';

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      titlePadding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      actionsPadding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.isStartingKm
                  ? AppColors.primaryBlue.withValues(alpha: 0.1)
                  : AppColors.successBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.isStartingKm
                  ? Icons.speed_rounded
                  : Icons.check_circle_outline_rounded,
              color: widget.isStartingKm
                  ? AppColors.primaryBlue
                  : AppColors.success,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.h3.copyWith(fontSize: 16),
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.isStartingKm
                  ? 'Enter current vehicle speedometer / odometer reading before starting journey to ${widget.order.customerName}.'
                  : 'Enter current odometer reading upon reaching destination to record distance travelled.',
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
            if (widget.order.vehicleRegistration != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primaryBlue.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.two_wheeler_rounded,
                      size: 16,
                      color: AppColors.primaryBlue,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Vehicle: ${widget.order.vehicleRegistration}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!widget.isStartingKm && widget.order.startingKm != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Starting Reading:', style: TextStyle(fontSize: 12)),
                    Text(
                      '${widget.order.startingKm!} km',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const Key('km_input_field'),
              controller: _controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: widget.isStartingKm
                    ? 'Starting KM'
                    : 'Ending KM',
                hintText: 'e.g. 1420.5',
                suffixText: 'km',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                prefixIcon: const Icon(Icons.add_road_rounded),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Kilometer reading is required';
                }
                final num = double.tryParse(v.trim());
                if (num == null) {
                  return 'Enter a valid numeric value';
                }
                return null;
              },
            ),
            if (_customError != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                _customError!,
                style: const TextStyle(color: AppColors.critical, fontSize: 12),
              ),
            ],
            if (!widget.isStartingKm) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Delivery Notes / Remarks',
                style: AppTextStyles.bodyStrong.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 4),
              TextFormField(
                key: const Key('delivery_notes_field'),
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'e.g. Delivered directly to customer, paid cash ₹450',
                  hintStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  prefixIcon: const Icon(Icons.note_alt_outlined),
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildQuickChip('Delivered to customer'),
                    _buildQuickChip('Cash collected'),
                    _buildQuickChip('Paid via UPI'),
                    _buildQuickChip('Handed to security / guard'),
                    _buildQuickChip('Left at doorstep'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          key: const Key('km_submit_button'),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.isStartingKm
                ? AppColors.primaryBlue
                : AppColors.success,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: _submit,
          child: Text(widget.isStartingKm ? 'Confirm & Start' : 'Confirm & Complete'),
        ),
      ],
    );
  }

  Widget _buildQuickChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.border),
        onPressed: () {
          final current = _notesController.text.trim();
          if (current.isEmpty) {
            _notesController.text = label;
          } else if (!current.contains(label)) {
            _notesController.text = '$current • $label';
          }
          _notesController.selection = TextSelection.fromPosition(
            TextPosition(offset: _notesController.text.length),
          );
        },
      ),
    );
  }
}
