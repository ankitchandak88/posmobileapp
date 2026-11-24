import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import 'app_button.dart';

/// Covers both generic errors and offline/network-failure states (per
/// master prompt section 10 — distinguish network errors visually).
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    this.isOffline = false,
    this.onRetry,
  });

  final String message;
  final bool isOffline;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.criticalBg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.critical.withValues(alpha: 0.20),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Icon(
                  isOffline
                      ? Icons.wifi_off_rounded
                      : Icons.error_outline_rounded,
                  size: 36,
                  color: AppColors.critical,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              isOffline ? 'You\'re offline' : 'Something went wrong',
              style: AppTextStyles.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Retry',
                onPressed: onRetry,
                fullWidth: false,
                icon: Icons.refresh,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
