import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/widgets.dart';

class SubmissionConfirmationScreen extends StatefulWidget {
  const SubmissionConfirmationScreen({
    super.key,
    required this.itemName,
    required this.type,
  });

  final String itemName;
  final String type;

  @override
  State<SubmissionConfirmationScreen> createState() =>
      _SubmissionConfirmationScreenState();
}

class _SubmissionConfirmationScreenState
    extends State<SubmissionConfirmationScreen> {
  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final itemName = widget.itemName;
    final type = widget.type;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  color: AppColors.successBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.success,
                  size: 56,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Submission Received',
                style: AppTextStyles.h1,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${type == 'inward' ? 'Supplier inward entry' : (type == 'stock_count' ? 'Stock count' : 'Expiry check')} for "$itemName" has been submitted and is pending approval in POS.',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxxl),
              AppButton(
                label: 'Scan Next Item',
                onPressed: () => context.go('/home'),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Back to Home',
                variant: AppButtonVariant.secondary,
                onPressed: () => context.go('/home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
