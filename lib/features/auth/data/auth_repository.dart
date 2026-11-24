import 'dart:convert';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_token_storage.dart';
import 'user_model.dart';

class AuthRepository {
  AuthRepository({ApiClient? apiClient, SecureTokenStorage? storage})
    : _apiClient = apiClient ?? ApiClient(),
      _storage = storage ?? SecureTokenStorage();

  final ApiClient _apiClient;
  final SecureTokenStorage _storage;

  Future<UserModel> login({
    required String email,
    required String password,
    bool isRider = false,
  }) async {
    final mode = isRider ? 'rider' : 'store_staff';
    if (isRider) {
      _apiClient.setBaseUrl(ApiConstants.riderDeliveryUrl);
    } else {
      _apiClient.setBaseUrl(ApiConstants.baseUrl);
    }

    final response = await _apiClient.request(
      ApiConstants.login,
      method: 'POST',
      data: {
        'email': email,
        'password': password,
        'device_name': 'Urban Pets Mobile App',
      },
    );

    final raw = response.data;
    final Map<String, dynamic> data;
    if (raw is Map<String, dynamic> && raw['data'] is Map<String, dynamic>) {
      data = raw['data'] as Map<String, dynamic>;
    } else if (raw is Map<String, dynamic>) {
      data = raw;
    } else {
      throw Exception('Unexpected response format');
    }

    final token = data['token'] as String;
    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    await _storage.saveTokenForMode(token, mode);
    await _storage.saveUserJsonForMode(jsonEncode(user.toJson()), mode);
    await _storage.saveLoginMode(mode);
    return user;
  }

  Future<UserModel?> switchMode(String targetMode) async {
    final token = await _storage.readTokenForMode(targetMode);
    if (token == null || token.isEmpty) return null;

    await _storage.saveLoginMode(targetMode);
    if (targetMode == 'rider') {
      _apiClient.setBaseUrl(ApiConstants.riderDeliveryUrl);
    } else {
      _apiClient.setBaseUrl(ApiConstants.baseUrl);
    }

    final userJson = await _storage.readUserJsonForMode(targetMode);
    if (userJson != null) {
      try {
        return UserModel.fromJson(
          jsonDecode(userJson) as Map<String, dynamic>,
        );
      } catch (_) {}
    }

    // Refresh profile if needed
    try {
      final meEndpoint = targetMode == 'rider' ? '/auth/me' : ApiConstants.me;
      final response = await _apiClient.request(meEndpoint);
      final raw = response.data;
      final Map<String, dynamic> userData;
      if (raw is Map<String, dynamic> && raw['data'] is Map<String, dynamic>) {
        userData = raw['data'] as Map<String, dynamic>;
      } else if (raw is Map<String, dynamic>) {
        userData = raw;
      } else {
        throw Exception('Unexpected response format');
      }
      final user = UserModel.fromJson(userData);
      await _storage.saveUserJsonForMode(jsonEncode(user.toJson()), targetMode);
      return user;
    } catch (_) {
      return null;
    }
  }

  Future<UserModel?> getUserForMode(String mode) async {
    final userJson = await _storage.readUserJsonForMode(mode);
    if (userJson == null) return null;
    try {
      return UserModel.fromJson(
        jsonDecode(userJson) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasLinkedRider() => _storage.hasRiderSession();
  Future<bool> hasLinkedStaff() => _storage.hasStaffSession();

  Future<UserModel?> loginWithSavedRole(String mode) async {
    final token = await _storage.readTokenForMode(mode);
    if (token == null || token.isEmpty) return null;
    return switchMode(mode);
  }

  Future<void> removeSavedAccount(String mode) async {
    await _storage.removeSavedAccount(mode);
  }

  Future<void> logoutCurrentMode({String? mode}) async {
    final active = mode ?? await _storage.readLoginMode() ?? 'store_staff';
    try {
      await _apiClient.request(ApiConstants.logout, method: 'POST');
    } catch (_) {}
    await _storage.clearMode(active);
  }

  Future<void> logout({bool keepSavedAccounts = true}) async {
    try {
      await _apiClient.request(ApiConstants.logout, method: 'POST');
    } catch (_) {
      // best-effort server-side invalidation; always clear local state
    }
    if (keepSavedAccounts) {
      await _storage.clearActiveSession();
    } else {
      await _storage.clear();
    }
  }

  Future<UserModel?> restoreSession() async {
    final loginMode = await _storage.readLoginMode();
    if (loginMode == null) {
      // No active session logged in (e.g. user logged out),
      // keep saved account credentials untouched for 1-tap re-login.
      return null;
    }

    final token = await _storage.readTokenForMode(loginMode);
    if (token == null || token.isEmpty) {
      return null;
    }

    final activeMode = loginMode;

    if (activeMode == 'rider') {
      _apiClient.setBaseUrl(ApiConstants.riderDeliveryUrl);
    } else {
      _apiClient.setBaseUrl(ApiConstants.baseUrl);
    }

    final cachedJson = await _storage.readUserJsonForMode(activeMode);
    if (cachedJson != null) {
      try {
        return UserModel.fromJson(
          jsonDecode(cachedJson) as Map<String, dynamic>,
        );
      } catch (_) {
        // fall through to network refresh
      }
    }
    try {
      final meEndpoint = activeMode == 'rider' ? '/auth/me' : ApiConstants.me;
      final response = await _apiClient.request(meEndpoint);
      final raw = response.data;
      final Map<String, dynamic> userData;
      if (raw is Map<String, dynamic> && raw['data'] is Map<String, dynamic>) {
        userData = raw['data'] as Map<String, dynamic>;
      } else if (raw is Map<String, dynamic>) {
        userData = raw;
      } else {
        throw Exception('Unexpected response format');
      }
      final user = UserModel.fromJson(userData);
      await _storage.saveUserJsonForMode(jsonEncode(user.toJson()), activeMode);
      return user;
    } catch (_) {
      await _storage.clearMode(activeMode);
      return null;
    }
  }
}
