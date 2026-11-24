import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/quick_unlock_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../state/auth_providers.dart';
import 'pin_pad.dart';

/// Shown on a fresh app launch when a session already exists and quick
/// unlock is enabled (`AuthStatus.locked`). Biometric mode auto-triggers the
/// OS prompt; PIN mode shows a keypad. Either path calls
/// `AuthController.unlock()` on success — the already-stored session token
/// is reused as-is, nothing is re-sent to the server. "Use password
/// instead" is always available.
class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  String? _mode;
  int _wrongAttempts = 0;
  String? _pinError;
  bool _biometricInFlight = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final service = ref.read(quickUnlockServiceProvider);
    final mode = await service.mode();
    final attempts = await service.failedPinAttempts();
    if (!mounted) return;
    setState(() {
      _mode = mode;
      _wrongAttempts = attempts;
    });
    if (attempts >= QuickUnlockService.maxPinAttempts) {
      ref.read(authControllerProvider.notifier).requireFullLogin();
      return;
    }
    if (mode == 'biometric') {
      _tryBiometric();
    }
  }

  Future<void> _tryBiometric() async {
    setState(() => _biometricInFlight = true);
    final ok = await ref
        .read(quickUnlockServiceProvider)
        .authenticateBiometric();
    if (!mounted) return;
    setState(() => _biometricInFlight = false);
    if (ok) {
      ref.read(authControllerProvider.notifier).unlock();
    }
  }

  Future<void> _onPinSubmitted(String pin) async {
    final service = ref.read(quickUnlockServiceProvider);
    final correct = await service.verifyPin(pin);
    if (!mounted) return;
    if (correct) {
      await service.resetFailedPinAttempts();
      ref.read(authControllerProvider.notifier).unlock();
      return;
    }
    final attempts = _wrongAttempts + 1;
    await service.recordFailedPinAttempt(attempts);
    if (attempts >= QuickUnlockService.maxPinAttempts) {
      ref.read(authControllerProvider.notifier).requireFullLogin();
      return;
    }
    setState(() {
      _wrongAttempts = attempts;
      _pinError =
          'Wrong PIN. ${QuickUnlockService.maxPinAttempts - attempts} '
          'attempt${QuickUnlockService.maxPinAttempts - attempts == 1 ? '' : 's'} left.';
    });
  }

  void _usePasswordInstead() {
    ref.read(authControllerProvider.notifier).requireFullLogin();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(child: _buildContent()),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final user = ref.watch(authControllerProvider).user;
    return Column(
      children: [
        const SizedBox(height: AppSpacing.xxxl),
        CircleAvatar(
          radius: 36,
          backgroundColor: AppColors.navy,
          child: Text(
            (user?.name.isNotEmpty ?? false)
                ? user!.name[0].toUpperCase()
                : '?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Welcome back, ${user?.name ?? ''}', style: AppTextStyles.h2),
        const Spacer(),
        if (_mode == 'biometric') ...[
          Icon(
            Icons.fingerprint,
            size: 72,
            color: _biometricInFlight ? AppColors.textMuted : AppColors.navy,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Verifying…', style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.lg),
          TextButton(
            key: const Key('retry_biometric_button'),
            onPressed: _biometricInFlight ? null : _tryBiometric,
            child: const Text('Try again'),
          ),
        ] else if (_mode == 'pin')
          PinPad(
            key: const Key('unlock_pin_pad'),
            length: QuickUnlockService.pinLength,
            errorText: _pinError,
            onSubmitted: _onPinSubmitted,
          ),
        const Spacer(),
        TextButton(
          key: const Key('use_password_instead_button'),
          onPressed: _usePasswordInstead,
          child: const Text('Use password instead'),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}
