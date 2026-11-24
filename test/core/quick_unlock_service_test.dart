import 'package:flutter_test/flutter_test.dart';
import 'package:urban_pets_verify/core/storage/quick_unlock_service.dart';
import 'package:urban_pets_verify/core/storage/secure_token_storage.dart';

import '../helpers/test_harness.dart';

/// An in-memory [SecureTokenStorage] (no platform channel) so these tests
/// can exercise the real read/write round-trip instead of no-ops.
class InMemoryTokenStorage extends SecureTokenStorage {
  String? _quickUnlockMode;
  String? _pinHash;
  String? _pinSalt;

  @override
  Future<String?> readToken() async => null;
  @override
  Future<String?> readUserJson() async => null;
  @override
  Future<void> saveToken(String token) async {}
  @override
  Future<void> saveUserJson(String userJson) async {}
  @override
  Future<void> clear() async {
    await clearQuickUnlock();
  }

  @override
  Future<void> saveQuickUnlockMode(String? mode) async {
    _quickUnlockMode = mode;
  }

  @override
  Future<String?> readQuickUnlockMode() async => _quickUnlockMode;

  @override
  Future<void> savePin({required String hash, required String salt}) async {
    _pinHash = hash;
    _pinSalt = salt;
  }

  @override
  Future<String?> readPinHash() async => _pinHash;

  int _failedPinAttempts = 0;

  @override
  Future<String?> readPinSalt() async => _pinSalt;

  @override
  Future<int> readFailedPinAttempts() async => _failedPinAttempts;

  @override
  Future<void> saveFailedPinAttempts(int attempts) async {
    _failedPinAttempts = attempts;
  }

  @override
  Future<void> clearFailedPinAttempts() async {
    _failedPinAttempts = 0;
  }

  @override
  Future<void> clearQuickUnlock() async {
    _quickUnlockMode = null;
    _pinHash = null;
    _pinSalt = null;
    _failedPinAttempts = 0;
  }
}

void main() {
  group('QuickUnlockService PIN hashing/verification', () {
    late QuickUnlockService service;

    setUp(() {
      service = QuickUnlockService(
        storage: InMemoryTokenStorage(),
        checker: FakeBiometricChecker(),
      );
    });

    test('a freshly-set PIN verifies correctly', () async {
      await service.enablePin('1234');
      expect(await service.verifyPin('1234'), isTrue);
    });

    test('a wrong PIN does not verify', () async {
      await service.enablePin('1234');
      expect(await service.verifyPin('0000'), isFalse);
    });

    test('mode() reports pin after enablePin', () async {
      await service.enablePin('1234');
      expect(await service.mode(), 'pin');
      expect(await service.isEnabled(), isTrue);
    });

    test('mode() reports biometric after enableBiometric', () async {
      await service.enableBiometric();
      expect(await service.mode(), 'biometric');
    });

    test(
      'verifyPin without a stored PIN returns false, not an error',
      () async {
        expect(await service.verifyPin('1234'), isFalse);
      },
    );

    test('the raw PIN is never stored — only a hash', () async {
      final storage = InMemoryTokenStorage();
      final s = QuickUnlockService(
        storage: storage,
        checker: FakeBiometricChecker(),
      );
      await s.enablePin('1234');
      expect(await storage.readPinHash(), isNot('1234'));
      expect(await storage.readPinHash(), isNotNull);
    });

    test('two different PINs produce different hashes', () async {
      final storageA = InMemoryTokenStorage();
      final storageB = InMemoryTokenStorage();
      await QuickUnlockService(
        storage: storageA,
        checker: FakeBiometricChecker(),
      ).enablePin('1234');
      await QuickUnlockService(
        storage: storageB,
        checker: FakeBiometricChecker(),
      ).enablePin('5678');
      expect(
        await storageA.readPinHash(),
        isNot(await storageB.readPinHash()),
      );
    });

    test('disable() clears the mode and PIN', () async {
      await service.enablePin('1234');
      await service.disable();
      expect(await service.mode(), isNull);
      expect(await service.verifyPin('1234'), isFalse);
    });

    test('isBiometricSupported delegates to the checker', () async {
      final supportedService = QuickUnlockService(
        storage: InMemoryTokenStorage(),
        checker: FakeBiometricChecker(supported: true),
      );
      expect(await supportedService.isBiometricSupported(), isTrue);
      expect(await service.isBiometricSupported(), isFalse);
    });
  });
}
