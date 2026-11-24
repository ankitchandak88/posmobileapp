import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Shows the signed variance between physical and system quantity
/// (manager/reviewer screens ONLY — staff-facing blind-count screens must
/// never construct this widget with a system-quantity-derived value).
class VarianceIndicator extends StatelessWidget {
  const VarianceIndicator({
    super.key,
    required this.variance,
    this.showArrow = true,
    this.fontSize = 15,
  });

  /// physical_qty - system_qty. Null means "not yet determinable" (shown as "-").
  final num? variance;

  /// Arrow glyph before the number (off on dense History rows, per reference).
  final bool showArrow;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    if (variance == null) {
      return const Text(
        '-',
        style: TextStyle(
          color: AppColors.varianceNeutral,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    final v = variance!;
    final isPositive = v > 0;
    final isZero = v == 0;
    final color = isZero
        ? AppColors.varianceNeutral
        : (isPositive
              ? AppColors.variancePositive
              : AppColors.varianceNegative);
    final sign = isPositive ? '+' : '';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isZero && showArrow) ...[
          Icon(
            isPositive ? Icons.arrow_upward : Icons.arrow_downward,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 2),
        ],
        Text(
          '$sign${v % 1 == 0 ? v.toInt() : v}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: fontSize,
          ),
        ),
      ],
    );
  }
}
