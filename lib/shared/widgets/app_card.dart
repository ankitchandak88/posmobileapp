import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Reusable elevated-but-flat card surface used across dashboard tiles,
/// list rows, and detail sections.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius =
        borderRadius ?? BorderRadius.circular(AppSpacing.radiusLg);
    final surfaceColor = color ?? AppColors.surface;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: effectiveRadius,
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: Material(
          color: Colors.transparent,
          child: onTap != null
              ? InkWell(
                  onTap: onTap,
                  child: Padding(padding: padding, child: child),
                )
              : Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
