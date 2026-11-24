import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/models.dart';

class BranchRepository {
  BranchRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<BranchModel>> list() async {
    final response = await _apiClient.request(ApiConstants.branches);
    final list = _extractList(response.data);
    return list
        .map((e) => BranchModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

/// The API always wraps list responses as `{"data": [...]}`; `response.data`
/// is therefore a `Map`, never a bare `List`. Checking the runtime type with
/// `is` (not `as`, which throws on a type mismatch instead of falling
/// through) avoids a `_Map is not a subtype of List` crash.
List<dynamic> _extractList(dynamic raw) {
  if (raw is List) return raw;
  if (raw is Map && raw['data'] is List) return raw['data'] as List;
  return const [];
}

class ExpiryBucketRepository {
  ExpiryBucketRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<ExpiryBucketModel>> list() async {
    final response = await _apiClient.request(ApiConstants.expiryBuckets);
    final list = _extractList(response.data);
    return list
        .map((e) => ExpiryBucketModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `PUT /v1/expiry-buckets/settings` (Manager/Owner only — business rule,
  /// 2026-10-10: bucket ranges must be configurable, not hardcoded). The
  /// server validates no gaps-at-zero/overlaps and returns the saved list.
  Future<List<ExpiryBucketModel>> updateSettings(
    List<ExpiryBucketModel> buckets,
  ) async {
    final response = await _apiClient.request(
      ApiConstants.expiryBucketSettings,
      method: 'PUT',
      data: {'buckets': [for (final b in buckets) b.toJson()]},
    );
    final list = _extractList(response.data);
    return list
        .map((e) => ExpiryBucketModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
