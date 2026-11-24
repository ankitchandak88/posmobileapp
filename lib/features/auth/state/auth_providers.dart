import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/auth_session.dart';
import '../../../core/storage/quick_unlock_service.dart';
import '../../../core/storage/secure_token_storage.dart';
import '../data/auth_repository.dart';
import '../data/user_model.dart';

final secureTokenStorageProvider = Provider<SecureTokenStorage>(
  (ref) => SecureTokenStorage(),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(tokenStorage: ref.read(secureTokenStorageProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    apiClient: ref.read(apiClientProvider),
    storage: ref.read(secureTokenStorageProvider),
  );
});

final quickUnlockServiceProvider = Provider<QuickUnlockService>((ref) {
  return QuickUnlockService(storage: ref.read(secureTokenStorageProvider));
});

/// [locked]: a session already exists in secure storage (the user logged in
/// before) and quick-unlock is enabled, but it hasn't been unlocked yet this
/// app launch — the router sends this to the PIN/biometric unlock screen
/// instead of straight to the dashboard or the full login form.
enum AuthStatus { unknown, authenticated, unauthenticated, locked }

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
    this.showQuickUnlockPrompt = false,
    this.activeMode = 'store_staff',
    this.hasLinkedRider = false,
    this.hasLinkedStaff = false,
    this.riderUser,
    this.staffUser,
  });

  final AuthStatus status;
  final UserModel? user;
  final String? errorMessage;

  /// True for exactly one state update right after a fresh password login
  /// where quick-unlock isn't configured yet — tells the UI to offer the
  /// one-time "enable quick unlock?" prompt. Never set on app-relaunch
  /// restores, so users aren't nagged every time they open the app.
  final bool showQuickUnlockPrompt;
  final String activeMode;
  final bool hasLinkedRider;
  final bool hasLinkedStaff;
  final UserModel? riderUser;
  final UserModel? staffUser;

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? errorMessage,
    bool? showQuickUnlockPrompt,
    String? activeMode,
    bool? hasLinkedRider,
    bool? hasLinkedStaff,
    UserModel? riderUser,
    UserModel? staffUser,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
      showQuickUnlockPrompt: showQuickUnlockPrompt ?? this.showQuickUnlockPrompt,
      activeMode: activeMode ?? this.activeMode,
      hasLinkedRider: hasLinkedRider ?? this.hasLinkedRider,
      hasLinkedStaff: hasLinkedStaff ?? this.hasLinkedStaff,
      riderUser: riderUser ?? this.riderUser,
      staffUser: staffUser ?? this.staffUser,
    );
  }

  static const initial = AuthState(status: AuthStatus.unknown);
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository, this._quickUnlock)
    : super(AuthState.initial) {
    AuthSessionNotifier.instance.onUnauthorized = () async {
      final hasRider = await _repository.hasLinkedRider();
      final hasStaff = await _repository.hasLinkedStaff();
      final riderUser = hasRider ? await _repository.getUserForMode('rider') : null;
      final staffUser = hasStaff ? await _repository.getUserForMode('store_staff') : null;
      state = AuthState(
        status: AuthStatus.unauthenticated,
        hasLinkedRider: hasRider,
        hasLinkedStaff: hasStaff,
        riderUser: riderUser,
        staffUser: staffUser,
      );
    };
    _restore();
  }

  final AuthRepository _repository;
  final QuickUnlockService _quickUnlock;
  bool loading = false;

  Future<void> _restore() async {
    final hasRider = await _repository.hasLinkedRider();
    final hasStaff = await _repository.hasLinkedStaff();
    final riderUser = hasRider ? await _repository.getUserForMode('rider') : null;
    final staffUser = hasStaff ? await _repository.getUserForMode('store_staff') : null;

    final user = await _repository.restoreSession();
    if (user == null) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        hasLinkedRider: hasRider,
        hasLinkedStaff: hasStaff,
        riderUser: riderUser,
        staffUser: staffUser,
      );
      return;
    }
    final quickUnlockEnabled = await _quickUnlock.isEnabled();
    final activeMode = user.isRider ? 'rider' : 'store_staff';

    state = AuthState(
      status: quickUnlockEnabled ? AuthStatus.locked : AuthStatus.authenticated,
      user: user,
      activeMode: activeMode,
      hasLinkedRider: hasRider,
      hasLinkedStaff: hasStaff,
      riderUser: riderUser,
      staffUser: staffUser,
    );
  }

  Future<bool> login(String email, String password, {bool isRider = false}) async {
    loading = true;
    state = state.copyWith(errorMessage: null);
    try {
      final user = await _repository.login(
        email: email,
        password: password,
        isRider: isRider,
      );
      final quickUnlockEnabled = await _quickUnlock.isEnabled();
      final hasRider = await _repository.hasLinkedRider();
      final hasStaff = await _repository.hasLinkedStaff();
      final riderUser = hasRider ? await _repository.getUserForMode('rider') : null;
      final staffUser = hasStaff ? await _repository.getUserForMode('store_staff') : null;

      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
        showQuickUnlockPrompt: !quickUnlockEnabled,
        activeMode: isRider ? 'rider' : 'store_staff',
        hasLinkedRider: hasRider,
        hasLinkedStaff: hasStaff,
        riderUser: riderUser,
        staffUser: staffUser,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: state.user != null ? state.status : AuthStatus.unauthenticated,
        errorMessage: e.toString(),
      );
      return false;
    } finally {
      loading = false;
    }
  }

  Future<bool> loginWithSavedRole(String mode) async {
    loading = true;
    state = state.copyWith(errorMessage: null);
    try {
      final user = await _repository.loginWithSavedRole(mode);
      if (user == null) {
        state = state.copyWith(
          errorMessage: 'Saved session expired. Please enter your password.',
        );
        return false;
      }
      final hasRider = await _repository.hasLinkedRider();
      final hasStaff = await _repository.hasLinkedStaff();
      final riderUser = hasRider ? await _repository.getUserForMode('rider') : null;
      final staffUser = hasStaff ? await _repository.getUserForMode('store_staff') : null;

      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
        activeMode: mode,
        hasLinkedRider: hasRider,
        hasLinkedStaff: hasStaff,
        riderUser: riderUser,
        staffUser: staffUser,
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    } finally {
      loading = false;
    }
  }

  Future<void> removeSavedAccount(String mode) async {
    await _repository.removeSavedAccount(mode);
    final hasRider = await _repository.hasLinkedRider();
    final hasStaff = await _repository.hasLinkedStaff();
    final riderUser = hasRider ? await _repository.getUserForMode('rider') : null;
    final staffUser = hasStaff ? await _repository.getUserForMode('store_staff') : null;

    state = state.copyWith(
      hasLinkedRider: hasRider,
      hasLinkedStaff: hasStaff,
      riderUser: riderUser,
      staffUser: staffUser,
    );
  }

  Future<bool> switchRole(String targetMode) async {
    loading = true;
    try {
      final user = await _repository.switchMode(targetMode);
      if (user == null) {
        return false;
      }
      final hasRider = await _repository.hasLinkedRider();
      final hasStaff = await _repository.hasLinkedStaff();
      final riderUser = hasRider ? await _repository.getUserForMode('rider') : null;
      final staffUser = hasStaff ? await _repository.getUserForMode('store_staff') : null;

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        activeMode: targetMode,
        hasLinkedRider: hasRider,
        hasLinkedStaff: hasStaff,
        riderUser: riderUser,
        staffUser: staffUser,
        errorMessage: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    } finally {
      loading = false;
    }
  }

  Future<void> logoutCurrentRole() async {
    await _repository.logoutCurrentMode(mode: state.activeMode);
    final otherMode = state.activeMode == 'rider' ? 'store_staff' : 'rider';
    final hasOther = otherMode == 'rider'
        ? await _repository.hasLinkedRider()
        : await _repository.hasLinkedStaff();

    if (hasOther) {
      await switchRole(otherMode);
    } else {
      await logout(keepSavedAccounts: true);
    }
  }

  /// Called after a correct PIN or successful biometric check from the
  /// unlock screen. Does not touch the server — the session token already
  /// in secure storage was valid, this just lifts the local gate.
  void unlock() {
    if (state.status != AuthStatus.locked) return;
    state = AuthState(
      status: AuthStatus.authenticated,
      user: state.user,
      activeMode: state.activeMode,
      hasLinkedRider: state.hasLinkedRider,
      hasLinkedStaff: state.hasLinkedStaff,
      riderUser: state.riderUser,
      staffUser: state.staffUser,
    );
  }

  /// "Use password instead" escape hatch from the unlock screen (forgotten
  /// PIN, biometric unavailable, a different user wants to sign in). Leaves
  /// the stored session/quick-unlock settings untouched — a fresh [login]
  /// overwrites them as usual.
  void requireFullLogin() {
    state = AuthState(
      status: AuthStatus.unauthenticated,
      hasLinkedRider: state.hasLinkedRider,
      hasLinkedStaff: state.hasLinkedStaff,
      riderUser: state.riderUser,
      staffUser: state.staffUser,
    );
  }

  void dismissQuickUnlockPrompt() {
    state = state.copyWith(showQuickUnlockPrompt: false);
  }

  Future<void> lockIfEnabled() async {
    if (state.status == AuthStatus.authenticated &&
        await _quickUnlock.isEnabled()) {
      state = AuthState(
        status: AuthStatus.locked,
        user: state.user,
        activeMode: state.activeMode,
        hasLinkedRider: state.hasLinkedRider,
        hasLinkedStaff: state.hasLinkedStaff,
        riderUser: state.riderUser,
        staffUser: state.staffUser,
      );
    }
  }

  Future<void> logout({bool keepSavedAccounts = true}) async {
    await _repository.logout(keepSavedAccounts: keepSavedAccounts);
    final hasRider = keepSavedAccounts ? await _repository.hasLinkedRider() : false;
    final hasStaff = keepSavedAccounts ? await _repository.hasLinkedStaff() : false;
    final riderUser = hasRider ? await _repository.getUserForMode('rider') : null;
    final staffUser = hasStaff ? await _repository.getUserForMode('store_staff') : null;

    state = AuthState(
      status: AuthStatus.unauthenticated,
      hasLinkedRider: hasRider,
      hasLinkedStaff: hasStaff,
      riderUser: riderUser,
      staffUser: staffUser,
    );
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    return AuthController(
      ref.read(authRepositoryProvider),
      ref.read(quickUnlockServiceProvider),
    );
  },
);
