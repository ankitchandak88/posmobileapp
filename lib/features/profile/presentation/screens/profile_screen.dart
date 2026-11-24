import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../auth/presentation/screens/pin_pad.dart';
import '../../../auth/presentation/widgets/role_switch_sheet.dart';
import '../../../auth/state/auth_providers.dart';
import '../../../dashboard/state/dashboard_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String? _quickUnlockMode;
  bool _loadingMode = true;

  @override
  void initState() {
    super.initState();
    _loadMode();
  }

  Future<void> _loadMode() async {
    final mode = await ref.read(quickUnlockServiceProvider).mode();
    if (!mounted) return;
    setState(() {
      _quickUnlockMode = mode;
      _loadingMode = false;
    });
  }

  Future<void> _disableQuickUnlock() async {
    await ref.read(quickUnlockServiceProvider).disable();
    _loadMode();
  }

  Future<void> _setPin() async {
    final pin = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const PinSetupScreen()),
    );
    if (pin != null) {
      await ref.read(quickUnlockServiceProvider).enablePin(pin);
      _loadMode();
    }
  }

  Future<void> _enableBiometric() async {
    final service = ref.read(quickUnlockServiceProvider);
    final supported = await service.isBiometricSupported();
    if (!supported) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Biometric unlock is not supported or not enrolled on this device.',
          ),
        ),
      );
      return;
    }
    final ok = await service.authenticateBiometric(
      reason: 'Confirm to enable quick unlock',
    );
    if (!mounted) return;
    if (ok) {
      await service.enableBiometric();
      _loadMode();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biometric unlock enabled.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometric verification cancelled or failed.'),
        ),
      );
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.criticalBg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.critical.withValues(alpha: 0.20),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.critical,
                  size: 28,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Log Out',
                style: AppTextStyles.h2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Are you sure you want to log out of Urban Pets? You will need your email and password to sign in again.',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                key: const Key('confirm_logout_button'),
                label: 'Log Out',
                variant: AppButtonVariant.danger,
                onPressed: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Cancel',
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(authControllerProvider.notifier).logout(keepSavedAccounts: true);
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    final branchesAsync = ref.watch(branchesProvider);
    final branchName = branchesAsync.maybeWhen(
      data: (branches) {
        if (user?.branchId == null) return 'All branches';
        for (final b in branches) {
          if (b.id == user!.branchId) return b.name;
        }
        return user?.branchId ?? '-';
      },
      orElse: () => user?.branchId ?? '-',
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primaryBlue.withValues(alpha: 0.25),
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 38,
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
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(user?.name ?? 'Unknown user', style: AppTextStyles.h2),
                  const SizedBox(height: 2),
                  Text(user?.email ?? '-', style: AppTextStyles.caption),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppCard(
              child: Column(
                children: [
                  _InfoRow(label: 'Role', value: user?.role ?? '-'),
                  const Divider(height: AppSpacing.xl),
                  _InfoRow(label: 'Branch', value: branchName),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Role & Multi-Account', style: AppTextStyles.h2),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.swap_horiz_rounded,
                          color: AppColors.primaryBlue,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.hasLinkedRider
                                  ? 'Store Staff & Delivery Rider linked'
                                  : 'Switch or link Delivery Rider account',
                              style: AppTextStyles.bodyStrong,
                            ),
                            Text(
                              auth.hasLinkedRider
                                  ? '1-tap switch between store and delivery'
                                  : 'Connect rider account to work on both roles without re-login',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    key: const Key('profile_switch_role_button'),
                    label: auth.hasLinkedRider
                        ? 'Switch Role / Account'
                        : 'Connect Delivery Rider',
                    icon: Icons.two_wheeler_rounded,
                    variant: AppButtonVariant.primary,
                    onPressed: () => RoleSwitchSheet.show(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Quick Unlock', style: AppTextStyles.h2),
            const SizedBox(height: AppSpacing.sm),
            if (_loadingMode)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_quickUnlockMode == null) ...[
              Text(
                'Sign in with your password each time you open the app, or '
                'turn on a faster way to unlock.',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                key: const Key('profile_enable_biometric_button'),
                label: 'Use Fingerprint / Face',
                icon: Icons.fingerprint,
                variant: AppButtonVariant.secondary,
                onPressed: _enableBiometric,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                key: const Key('profile_set_pin_button'),
                label: 'Set a 4-digit PIN',
                icon: Icons.pin_rounded,
                variant: AppButtonVariant.secondary,
                onPressed: _setPin,
              ),
            ] else
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _quickUnlockMode == 'biometric'
                              ? Icons.fingerprint
                              : Icons.pin_rounded,
                          color: AppColors.navy,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _quickUnlockMode == 'biometric'
                                ? 'Fingerprint / Face unlock is on'
                                : 'PIN unlock is on',
                            style: AppTextStyles.bodyStrong,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_quickUnlockMode == 'pin')
                      AppButton(
                        key: const Key('profile_change_pin_button'),
                        label: 'Change PIN',
                        variant: AppButtonVariant.secondary,
                        onPressed: _setPin,
                      ),
                    if (_quickUnlockMode == 'pin')
                      const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      key: const Key('profile_disable_quick_unlock_button'),
                      label: 'Turn off quick unlock',
                      variant: AppButtonVariant.secondary,
                      onPressed: _disableQuickUnlock,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.xxl),
            AppButton(
              label: 'Logout',
              variant: AppButtonVariant.danger,
              icon: Icons.logout,
              onPressed: _confirmLogout,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.caption),
        Text(value, style: AppTextStyles.bodyStrong),
      ],
    );
  }
}
