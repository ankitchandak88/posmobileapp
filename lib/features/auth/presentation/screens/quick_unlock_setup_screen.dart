import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../state/auth_providers.dart';
import 'pin_pad.dart';

/// One-time, skippable prompt shown right after a fresh password login when
/// quick-unlock isn't configured yet (see [AuthState.showQuickUnlockPrompt]).
class QuickUnlockSetupScreen extends ConsumerStatefulWidget {
  const QuickUnlockSetupScreen({super.key});

  @override
  ConsumerState<QuickUnlockSetupScreen> createState() =>
      _QuickUnlockSetupScreenState();
}

class _QuickUnlockSetupScreenState
    extends ConsumerState<QuickUnlockSetupScreen> {
  bool _checkingBiometric = true;
  bool _biometricSupported = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final supported = await ref
        .read(quickUnlockServiceProvider)
        .isBiometricSupported();
    if (!mounted) return;
    setState(() {
      _biometricSupported = supported;
      _checkingBiometric = false;
    });
  }

  void _finish() {
    ref.read(authControllerProvider.notifier).dismissQuickUnlockPrompt();
    if (mounted) context.go('/home');
  }

  Future<void> _enableBiometric() async {
    final service = ref.read(quickUnlockServiceProvider);
    final ok = await service.authenticateBiometric(
      reason: 'Confirm to enable quick unlock',
    );
    if (ok) {
      await service.enableBiometric();
    }
    _finish();
  }

  Future<void> _setPin() async {
    final pin = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const PinSetupScreen()),
    );
    if (pin != null) {
      await ref.read(quickUnlockServiceProvider).enablePin(pin);
    }
    _finish();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xxxl),
              const Icon(
                Icons.lock_clock_rounded,
                size: 56,
                color: AppColors.navy,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Enable quick unlock?',
                style: AppTextStyles.h1,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                "Sign in once, then use your fingerprint, face, or a 4-digit "
                "PIN to get back in instead of typing your password every "
                'time.',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              if (!_checkingBiometric && _biometricSupported) ...[
                AppButton(
                  key: const Key('enable_biometric_button'),
                  label: 'Use Fingerprint / Face',
                  icon: Icons.fingerprint,
                  onPressed: _enableBiometric,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              AppButton(
                key: const Key('set_pin_button'),
                label: 'Set a 4-digit PIN',
                icon: Icons.pin_rounded,
                variant: AppButtonVariant.secondary,
                onPressed: _setPin,
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                key: const Key('skip_quick_unlock_button'),
                onPressed: _finish,
                child: const Text('Skip, always use password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
