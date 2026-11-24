import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the bearer auth token (and minimal user context) in the platform
/// secure keystore/keychain — NEVER in SharedPreferences/plain storage.
class SecureTokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'urban_pets_auth_token';
  static const _userKey = 'urban_pets_auth_user_json';
  static const _loginModeKey = 'urban_pets_login_mode';

  static const _tokenStaffKey = 'urban_pets_auth_token_staff';
  static const _userStaffKey = 'urban_pets_auth_user_json_staff';
  static const _tokenRiderKey = 'urban_pets_auth_token_rider';
  static const _userRiderKey = 'urban_pets_auth_user_json_rider';

  // Quick-unlock (local gate in front of the stored session above — see
  // QuickUnlockService). 'biometric' or 'pin'; absent/null = full password
  // login required every time (the default, unchanged behaviour).
  static const _quickUnlockModeKey = 'urban_pets_quick_unlock_mode';
  static const _pinHashKey = 'urban_pets_quick_unlock_pin_hash';
  static const _pinSaltKey = 'urban_pets_quick_unlock_pin_salt';
  static const _pinAttemptsKey = 'urban_pets_quick_unlock_pin_attempts';

  Future<void> saveToken(String token) async {
    final activeMode = await readLoginMode() ?? 'store_staff';
    await saveTokenForMode(token, activeMode);
  }

  Future<void> saveTokenForMode(String token, String mode) async {
    if (mode == 'rider') {
      await _storage.write(key: _tokenRiderKey, value: token);
    } else {
      await _storage.write(key: _tokenStaffKey, value: token);
    }
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> readToken() async {
    final activeMode = await readLoginMode() ?? 'store_staff';
    return readTokenForMode(activeMode);
  }

  Future<String?> readTokenForMode(String mode) async {
    if (mode == 'rider') {
      final token = await _storage.read(key: _tokenRiderKey);
      if (token != null && token.isNotEmpty) return token;
      final legacyMode = await _storage.read(key: _loginModeKey);
      if (legacyMode == 'rider') {
        return _storage.read(key: _tokenKey);
      }
      return null;
    } else {
      final token = await _storage.read(key: _tokenStaffKey);
      if (token != null && token.isNotEmpty) return token;
      final legacyMode = await _storage.read(key: _loginModeKey);
      if (legacyMode != 'rider') {
        return _storage.read(key: _tokenKey);
      }
      return null;
    }
  }

  Future<void> saveUserJson(String userJson) async {
    final activeMode = await readLoginMode() ?? 'store_staff';
    await saveUserJsonForMode(userJson, activeMode);
  }

  Future<void> saveUserJsonForMode(String userJson, String mode) async {
    if (mode == 'rider') {
      await _storage.write(key: _userRiderKey, value: userJson);
    } else {
      await _storage.write(key: _userStaffKey, value: userJson);
    }
    await _storage.write(key: _userKey, value: userJson);
  }

  Future<String?> readUserJson() async {
    final activeMode = await readLoginMode() ?? 'store_staff';
    return readUserJsonForMode(activeMode);
  }

  Future<String?> readUserJsonForMode(String mode) async {
    if (mode == 'rider') {
      final u = await _storage.read(key: _userRiderKey);
      if (u != null && u.isNotEmpty) return u;
      final legacyMode = await _storage.read(key: _loginModeKey);
      if (legacyMode == 'rider') {
        return _storage.read(key: _userKey);
      }
      return null;
    } else {
      final u = await _storage.read(key: _userStaffKey);
      if (u != null && u.isNotEmpty) return u;
      final legacyMode = await _storage.read(key: _loginModeKey);
      if (legacyMode != 'rider') {
        return _storage.read(key: _userKey);
      }
      return null;
    }
  }

  Future<void> saveLoginMode(String mode) =>
      _storage.write(key: _loginModeKey, value: mode);

  Future<String?> readLoginMode() => _storage.read(key: _loginModeKey);

  Future<bool> hasStaffSession() async {
    final t = await readTokenForMode('store_staff');
    return t != null && t.isNotEmpty;
  }

  Future<bool> hasRiderSession() async {
    final t = await readTokenForMode('rider');
    return t != null && t.isNotEmpty;
  }

  /// Clears only the active session pointer so the app logs out to the
  /// login screen, but preserves saved connected credentials for 1-tap re-login.
  Future<void> clearActiveSession() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
    await _storage.delete(key: _loginModeKey);
  }

  /// Permanently removes a saved linked account (Staff or Rider).
  Future<void> removeSavedAccount(String mode) async {
    if (mode == 'rider') {
      await _storage.delete(key: _tokenRiderKey);
      await _storage.delete(key: _userRiderKey);
    } else {
      await _storage.delete(key: _tokenStaffKey);
      await _storage.delete(key: _userStaffKey);
    }
    final activeMode = await readLoginMode();
    if (activeMode == mode) {
      await clearActiveSession();
    }
  }

  Future<void> clearMode(String mode) async {
    await removeSavedAccount(mode);
    final otherMode = mode == 'rider' ? 'store_staff' : 'rider';
    final otherToken = await readTokenForMode(otherMode);
    if (otherToken != null && otherToken.isNotEmpty) {
      await saveLoginMode(otherMode);
    } else {
      await clear();
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
    await _storage.delete(key: _tokenStaffKey);
    await _storage.delete(key: _userStaffKey);
    await _storage.delete(key: _tokenRiderKey);
    await _storage.delete(key: _userRiderKey);
    await _storage.delete(key: _loginModeKey);
    await clearQuickUnlock();
  }

  Future<void> saveQuickUnlockMode(String? mode) => mode == null
      ? _storage.delete(key: _quickUnlockModeKey)
      : _storage.write(key: _quickUnlockModeKey, value: mode);

  Future<String?> readQuickUnlockMode() =>
      _storage.read(key: _quickUnlockModeKey);

  Future<void> savePin({required String hash, required String salt}) async {
    await _storage.write(key: _pinHashKey, value: hash);
    await _storage.write(key: _pinSaltKey, value: salt);
    await clearFailedPinAttempts();
  }

  Future<String?> readPinHash() => _storage.read(key: _pinHashKey);

  Future<String?> readPinSalt() => _storage.read(key: _pinSaltKey);

  Future<int> readFailedPinAttempts() async {
    final raw = await _storage.read(key: _pinAttemptsKey);
    return int.tryParse(raw ?? '0') ?? 0;
  }

  Future<void> saveFailedPinAttempts(int attempts) =>
      _storage.write(key: _pinAttemptsKey, value: attempts.toString());

  Future<void> clearFailedPinAttempts() =>
      _storage.delete(key: _pinAttemptsKey);

  /// Clears quick-unlock only (mode + PIN), leaving the real session token
  /// untouched. Used when the user turns quick unlock off from Profile.
  Future<void> clearQuickUnlock() async {
    await _storage.delete(key: _quickUnlockModeKey);
    await _storage.delete(key: _pinHashKey);
    await _storage.delete(key: _pinSaltKey);
    await clearFailedPinAttempts();
  }
}
