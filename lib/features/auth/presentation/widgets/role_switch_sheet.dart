import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../state/auth_providers.dart';

class RoleSwitchSheet extends ConsumerStatefulWidget {
  const RoleSwitchSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const RoleSwitchSheet(),
    );
  }

  @override
  ConsumerState<RoleSwitchSheet> createState() => _RoleSwitchSheetState();
}

class _RoleSwitchSheetState extends ConsumerState<RoleSwitchSheet> {
  bool _connectingRider = false;
  bool _connectingStaff = false;
  bool _submitting = false;
  String? _errorMessage;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleConnect({required bool isRider}) async {
    setState(() => _errorMessage = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final success = await ref.read(authControllerProvider.notifier).login(
          email,
          password,
          isRider: isRider,
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (success) {
      Navigator.of(context).pop();
      if (context.mounted) {
        try {
          if (isRider) {
            context.go('/rider-deliveries');
          } else {
            context.go('/home');
          }
        } catch (_) {}
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isRider
                ? 'Delivery Rider connected & switched!'
                : 'Store Staff connected & switched!',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      final msg = ref.read(authControllerProvider).errorMessage;
      setState(() => _errorMessage = msg ?? 'Login failed. Please check credentials.');
    }
  }

  Future<void> _handleSwitch(String targetMode) async {
    final success = await ref
        .read(authControllerProvider.notifier)
        .switchRole(targetMode);

    if (!mounted) return;
    Navigator.of(context).pop();

    if (success) {
      if (context.mounted) {
        try {
          if (targetMode == 'rider') {
            context.go('/rider-deliveries');
          } else {
            context.go('/home');
          }
        } catch (_) {}
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            targetMode == 'rider'
                ? 'Switched to Delivery Rider Mode'
                : 'Switched to Store Staff Mode',
          ),
          backgroundColor: AppColors.primaryBlue,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to switch role. Please try again.'),
          backgroundColor: AppColors.critical,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isCurrentRider = auth.user?.isRider ?? false;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Title
            Row(
              children: [
                const Icon(
                  Icons.swap_horiz_rounded,
                  color: AppColors.primaryBlue,
                  size: 26,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Switch Profile / Role',
                  style: AppTextStyles.h2,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Switch between Store Operations and Delivery Rider with 1 tap.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Inline Connect Form if user clicked Connect
            if (_connectingRider || _connectingStaff) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.4)),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _connectingRider
                                ? Icons.two_wheeler_rounded
                                : Icons.storefront_rounded,
                            color: AppColors.primaryBlue,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            _connectingRider
                                ? 'Connect Delivery Rider'
                                : 'Connect Store Staff',
                            style: AppTextStyles.h3.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.navy,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => setState(() {
                              _connectingRider = false;
                              _connectingStaff = false;
                              _errorMessage = null;
                            }),
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.criticalBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppColors.critical,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: _connectingRider
                              ? 'Rider Email'
                              : 'Store Staff Email',
                          prefixIcon: const Icon(Icons.email_outlined, size: 20),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Email required' : null,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline, size: 20),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        obscureText: true,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Password required' : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _submitting
                              ? null
                              : () => _handleConnect(isRider: _connectingRider),
                          child: _submitting
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _connectingRider
                                      ? 'Connect & Switch to Rider'
                                      : 'Connect & Switch to Staff',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // 1. Store Staff Account Card
            _buildRoleCard(
              context: context,
              title: 'Store Staff',
              subtitle: 'Stock count, Expiry verification, Inward & Tasks',
              icon: Icons.storefront_rounded,
              isCurrent: !isCurrentRider,
              isLinked: auth.hasLinkedStaff,
              user: auth.staffUser ?? (!isCurrentRider ? auth.user : null),
              onSwitch: () => _handleSwitch('store_staff'),
              onConnect: () => setState(() {
                _connectingStaff = true;
                _connectingRider = false;
                _emailController.clear();
                _passwordController.clear();
                _errorMessage = null;
              }),
            ),
            const SizedBox(height: AppSpacing.md),

            // 2. Delivery Rider Account Card
            _buildRoleCard(
              context: context,
              title: 'Delivery Rider',
              subtitle: 'Assigned orders, Navigation & Customer deliveries',
              icon: Icons.two_wheeler_rounded,
              isCurrent: isCurrentRider,
              isLinked: auth.hasLinkedRider,
              user: auth.riderUser ?? (isCurrentRider ? auth.user : null),
              onSwitch: () => _handleSwitch('rider'),
              onConnect: () => setState(() {
                _connectingRider = true;
                _connectingStaff = false;
                _emailController.clear();
                _passwordController.clear();
                _errorMessage = null;
              }),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Logout row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.critical,
                      side: const BorderSide(color: AppColors.critical),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.logout, size: 16),
                    label: Text(
                      isCurrentRider ? 'Sign Out Rider' : 'Sign Out Staff',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await ref
                          .read(authControllerProvider.notifier)
                          .logoutCurrentRole();
                    },
                  ),
                ),
                if (auth.hasLinkedStaff && auth.hasLinkedRider) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.power_settings_new, size: 16),
                      label: const Text(
                        'Sign Out All',
                        style: TextStyle(fontSize: 12),
                      ),
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await ref.read(authControllerProvider.notifier).logout();
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isCurrent,
    required bool isLinked,
    required dynamic user,
    required VoidCallback onSwitch,
    required VoidCallback onConnect,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isCurrent
            ? AppColors.primaryBlue.withValues(alpha: 0.06)
            : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: isCurrent ? AppColors.primaryBlue : AppColors.border,
          width: isCurrent ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isCurrent
                  ? AppColors.primaryBlue
                  : AppColors.navy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isCurrent ? Colors.white : AppColors.navy,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.h3.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'ACTIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                if (isLinked && user != null && user.name.isNotEmpty) ...[
                  Text(
                    '${user.name} (${user.email})',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ] else ...[
                  Text(
                    subtitle,
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (isCurrent)
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.primaryBlue,
              size: 22,
            )
          else if (isLinked)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: onSwitch,
              child: const Text(
                'Switch',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            )
          else
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryBlue,
                side: const BorderSide(color: AppColors.primaryBlue),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: onConnect,
              child: const Text(
                '+ Connect',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}
