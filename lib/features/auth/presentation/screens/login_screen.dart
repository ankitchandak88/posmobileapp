import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../state/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _submitting = false;
  bool _isRider = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 4) return 'Password is too short';
    return null;
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _submitting = true);
    final success = await ref
        .read(authControllerProvider.notifier)
        .login(
          _emailController.text.trim(),
          _passwordController.text,
          isRider: _isRider,
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (success) {
      if (context.mounted) {
        try {
          if (_isRider) {
            context.go('/rider-deliveries');
          } else {
            context.go('/home');
          }
        } catch (_) {}
      }
    } else {
      final message = ref.read(authControllerProvider).errorMessage;
      setState(
        () => _errorMessage = message ?? 'Login failed. Please try again.',
      );
    }
  }

  Future<void> _handleSavedLogin(String mode) async {
    setState(() {
      _errorMessage = null;
      _submitting = true;
    });
    final success = await ref
        .read(authControllerProvider.notifier)
        .loginWithSavedRole(mode);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (success) {
      if (context.mounted) {
        try {
          if (mode == 'rider') {
            context.go('/rider-deliveries');
          } else {
            context.go('/home');
          }
        } catch (_) {}
      }
    } else {
      final msg = ref.read(authControllerProvider).errorMessage;
      setState(
        () => _errorMessage =
            msg ?? 'Saved session expired. Please enter password.',
      );
    }
  }

  Widget _buildSavedAccountCard({
    required String title,
    required String subtitle,
    required String roleBadge,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    required VoidCallback onRemove,
    required Key key,
  }) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          onTap: _submitting ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              roleBadge,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: iconColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _submitting ? null : onTap,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '1-Tap Login',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.arrow_forward_rounded, size: 12),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  tooltip: 'Forget account',
                  onPressed: _submitting ? null : onRemove,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final hasAnySaved = authState.hasLinkedStaff || authState.hasLinkedRider;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xxxl),
                Center(
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/branding/logo_orange.png',
                        height: 108,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _isRider
                            ? 'Home Delivery & Tracking'
                            : 'Stock & Expiry Verification',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                if (hasAnySaved) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.people_outline_rounded,
                          size: 16,
                          color: AppColors.primaryBlue,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Connected Accounts',
                          style: AppTextStyles.h3.copyWith(fontSize: 14),
                        ),
                        const Spacer(),
                        const Text(
                          '1-Tap Sign In',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (authState.hasLinkedStaff && authState.staffUser != null)
                    _buildSavedAccountCard(
                      key: const Key('login_saved_staff_card'),
                      title: authState.staffUser!.name.isNotEmpty
                          ? authState.staffUser!.name
                          : 'Store Staff',
                      subtitle: authState.staffUser!.email,
                      roleBadge: 'Store Staff',
                      icon: Icons.storefront_rounded,
                      iconColor: AppColors.primaryBlue,
                      onTap: () => _handleSavedLogin('store_staff'),
                      onRemove: () => ref
                          .read(authControllerProvider.notifier)
                          .removeSavedAccount('store_staff'),
                    ),
                  if (authState.hasLinkedRider && authState.riderUser != null)
                    _buildSavedAccountCard(
                      key: const Key('login_saved_rider_card'),
                      title: authState.riderUser!.name.isNotEmpty
                          ? authState.riderUser!.name
                          : 'Delivery Rider',
                      subtitle: authState.riderUser!.email,
                      roleBadge: 'Rider',
                      icon: Icons.two_wheeler_rounded,
                      iconColor: AppColors.warning,
                      onTap: () => _handleSavedLogin('rider'),
                      onRemove: () => ref
                          .read(authControllerProvider.notifier)
                          .removeSavedAccount('rider'),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        child: Text(
                          'or sign in with password',
                          style: AppTextStyles.caption.copyWith(fontSize: 11),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Login Mode Selector
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          key: const Key('login_toggle_staff'),
                          onTap: () => setState(() => _isRider = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: !_isRider
                                  ? AppColors.primaryBlue
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Store Staff',
                              style: TextStyle(
                                color: !_isRider
                                    ? Colors.white
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          key: const Key('login_toggle_rider'),
                          onTap: () => setState(() => _isRider = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _isRider
                                  ? AppColors.primaryBlue
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Delivery Rider',
                              style: TextStyle(
                                color: _isRider
                                    ? Colors.white
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Welcome Back',
                  style: AppTextStyles.h1,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Sign in to continue',
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xxl),
                if (_errorMessage != null) ...[
                  Container(
                    key: const Key('login_error_banner'),
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.criticalBg,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.critical,
                          size: 18,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppColors.critical,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                AppTextField(
                  label: 'Email',
                  controller: _emailController,
                  hintText: 'you@urbanpets.com',
                  prefixIcon: Icons.alternate_email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: _validateEmail,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Password',
                  controller: _passwordController,
                  hintText: 'Enter your password',
                  prefixIcon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  validator: _validatePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                AppButton(
                  label: 'Login',
                  loading: _submitting,
                  onPressed: _submitting ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
