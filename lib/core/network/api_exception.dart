/// Normalized exception surfaced to the UI layer for any failed API call.
class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.isNetworkError = false,
    this.isUnauthorized = false,
  });

  final String message;
  final int? statusCode;
  final bool isNetworkError;
  final bool isUnauthorized;

  @override
  String toString() => message;
}
