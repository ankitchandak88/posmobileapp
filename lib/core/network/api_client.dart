import 'package:dio/dio.dart';

import '../constants/api_constants.dart';
import '../storage/secure_token_storage.dart';
import 'api_exception.dart';
import 'auth_session.dart';

/// Thin wrapper around a configured [Dio] instance:
/// - attaches the bearer token from secure storage on every request
/// - clears the token and notifies the app on 401
/// - retries once on a pure network/timeout error (not on 4xx/5xx)
/// - normalizes failures into [ApiException]
class ApiClient {
  ApiClient({SecureTokenStorage? tokenStorage, Dio? dio})
    : _tokenStorage = tokenStorage ?? SecureTokenStorage(),
      _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: ApiConstants.baseUrl,
              connectTimeout: ApiConstants.connectTimeout,
              receiveTimeout: ApiConstants.receiveTimeout,
              headers: {'Accept': 'application/json'},
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final path = options.path;
          final baseUrl = options.baseUrl;
          final isRiderRequest = path.contains('urban.indianpetcompany.com') ||
              baseUrl.contains('urban.indianpetcompany.com') ||
              path.startsWith('/orders') ||
              path.startsWith('/vehicles');

          String? token;
          if (isRiderRequest) {
            token = await _tokenStorage.readTokenForMode('rider');
            // Ensure rider delivery baseUrl if relative
            if (!path.startsWith('http') &&
                !baseUrl.contains('urban.indianpetcompany.com')) {
              options.baseUrl = ApiConstants.riderDeliveryUrl;
            }
          } else {
            token = await _tokenStorage.readTokenForMode('store_staff');
            // Ensure store pos baseUrl if relative
            if (!path.startsWith('http') &&
                !baseUrl.contains('pos.indianpetcompany.com') &&
                !baseUrl.contains('pos.ramdevcar.shop')) {
              options.baseUrl = ApiConstants.baseUrl;
            }
          }

          token ??= await _tokenStorage.readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            final path = error.requestOptions.path;
            final baseUrl = error.requestOptions.baseUrl;
            final isRiderRequest = path.contains('urban.indianpetcompany.com') ||
                baseUrl.contains('urban.indianpetcompany.com') ||
                path.startsWith('/orders') ||
                path.startsWith('/vehicles');

            final failedMode = isRiderRequest ? 'rider' : 'store_staff';
            final activeMode = await _tokenStorage.readLoginMode() ?? 'store_staff';

            // Only notify unauthorized if the active mode itself failed auth
            if (activeMode == failedMode) {
              await _tokenStorage.clearActiveSession();
              AuthSessionNotifier.instance.notifyUnauthorized();
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  final SecureTokenStorage _tokenStorage;

  Dio get dio => _dio;

  void setBaseUrl(String newBaseUrl) {
    _dio.options.baseUrl = newBaseUrl;
  }

  Future<Response<dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? queryParameters,
    dynamic data,
    ResponseType? responseType,
  }) async {
    try {
      return await _dio.request(
        path,
        queryParameters: queryParameters,
        data: data,
        options: Options(method: method, responseType: responseType),
      );
    } on DioException catch (e) {
      if (_isNetworkError(e)) {
        // retry exactly once on pure network/timeout failure
        try {
          return await _dio.request(
            path,
            queryParameters: queryParameters,
            data: data,
            options: Options(method: method, responseType: responseType),
          );
        } on DioException catch (retryError) {
          throw _toApiException(retryError);
        }
      }
      throw _toApiException(e);
    }
  }

  bool _isNetworkError(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError;
  }

  ApiException _toApiException(DioException e) {
    if (_isNetworkError(e)) {
      return ApiException(
        message: 'Network error. Please check your connection and try again.',
        isNetworkError: true,
      );
    }
    final statusCode = e.response?.statusCode;
    if (statusCode == 401) {
      return ApiException(
        message: 'Session expired. Please log in again.',
        statusCode: 401,
        isUnauthorized: true,
      );
    }
    final data = e.response?.data;
    String? serverMessage;
    if (data is Map && data['message'] is String) {
      serverMessage = data['message'] as String;
    }
    return ApiException(
      message: serverMessage ?? 'Something went wrong (status $statusCode).',
      statusCode: statusCode,
    );
  }
}
