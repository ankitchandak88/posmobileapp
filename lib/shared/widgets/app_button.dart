import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

enum AppButtonVariant { primary, secondary, danger, text }

/// Primary design-system button with a built-in loading state and large
/// touch target, matching the reference screenshots' bold blue CTAs.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.icon,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool loading;
  final IconData? icon;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final spinnerColor = switch (variant) {
      AppButtonVariant.secondary ||
      AppButtonVariant.text => AppColors.primaryBlue,
      _ => Colors.white,
    };

    final child = loading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              strokeCap: StrokeCap.round,
              color: spinnerColor,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(label),
            ],
          );

    final isDisabled = onPressed == null || loading;
    final button = switch (variant) {
      AppButtonVariant.primary => ElevatedButton(
        onPressed: isDisabled ? null : onPressed,
        child: child,
      ),
      AppButtonVariant.danger => ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.critical,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(AppSpacing.touchTarget + 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
        onPressed: isDisabled ? null : onPressed,
        child: child,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: isDisabled ? null : onPressed,
        child: child,
      ),
      AppButtonVariant.text => TextButton(
        onPressed: isDisabled ? null : onPressed,
        child: child,
      ),
    };

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}
