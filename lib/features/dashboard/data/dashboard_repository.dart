import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/models.dart';

/// Live client for `GET /v1/dashboard/summary` — see
/// URBANPETS_API_DOCUMENTATION.md "Dashboard" section. The response shape
/// differs by caller role (handled by [DashboardModel], not here).
class DashboardRepository {
  DashboardRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// [branchId] is optional: omitted, a Manager defaults to their own
  /// branch and an Owner aggregates across all branches; passed, it scopes
  /// (or, for a Manager, is validated against) a specific branch.
  Future<DashboardModel> summary({String? branchId}) async {
    final response = await _apiClient.request(
      ApiConstants.dashboardSummary,
      queryParameters: branchId != null ? {'branch_id': branchId} : null,
    );
    final data = response.data is Map && response.data['data'] != null
        ? response.data['data']
        : response.data;
    return DashboardModel.fromJson(data as Map<String, dynamic>);
  }
}
