import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';

import 'secure_token_storage.dart';

/// Thin wrapper around `local_auth` so it can be mocked in widget tests
/// (the real plugin cannot run on the test harness / has no platform
/// implementation there).
abstract class BiometricChecker {
  Future<bool> isSupported();
  Future<bool> authenticate(String reason);
}

class LocalAuthBiometricChecker implements BiometricChecker {
  final _auth = LocalAuthentication();

  @override
  Future<bool> isSupported() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final deviceSupported = await _auth.isDeviceSupported();
      return canCheck && deviceSupported;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

/// Local-only gate in front of the already-stored Sanctum session token
/// (see [SecureTokenStorage]). Never re-authenticates with the server — a
/// successful PIN/biometric check just lets the app proceed with the token
/// it already has. The raw PIN itself is never stored, only a salted hash.
class QuickUnlockService {
  QuickUnlockService({SecureTokenStorage? storage, BiometricChecker? checker})
    : _storage = storage ?? SecureTokenStorage(),
      _checker = checker ?? LocalAuthBiometricChecker();

  final SecureTokenStorage _storage;
  final BiometricChecker _checker;

  static const pinLength = 4;
  static const maxPinAttempts = 3;

  Future<String?> mode() => _storage.readQuickUnlockMode();

  Future<bool> isEnabled() async => (await mode()) != null;

  Future<bool> isBiometricSupported() => _checker.isSupported();

  Future<bool> authenticateBiometric({
    String reason = 'Unlock Urban Pets',
  }) => _checker.authenticate(reason);

  Future<void> enableBiometric() => _storage.saveQuickUnlockMode('biometric');

  Future<void> enablePin(String pin) async {
    final salt = _generateSalt();
    final hash = _hash(pin, salt);
    await _storage.savePin(hash: hash, salt: salt);
    await _storage.saveQuickUnlockMode('pin');
  }

  Future<bool> verifyPin(String pin) async {
    final hash = await _storage.readPinHash();
    final salt = await _storage.readPinSalt();
    if (hash == null || salt == null) return false;
    return _hash(pin, salt) == hash;
  }

  Future<int> failedPinAttempts() => _storage.readFailedPinAttempts();

  Future<void> recordFailedPinAttempt(int count) =>
      _storage.saveFailedPinAttempts(count);

  Future<void> resetFailedPinAttempts() => _storage.clearFailedPinAttempts();

  Future<void> disable() => _storage.clearQuickUnlock();

  String _generateSalt() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _hash(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }
}
