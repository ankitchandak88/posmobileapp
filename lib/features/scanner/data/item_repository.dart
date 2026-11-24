import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/models.dart';

class ItemRepository {
  ItemRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<ItemModel>> search(String query) async {
    if (query.trim().isEmpty) return [];
    final response = await _apiClient.request(
      ApiConstants.itemsSearch,
      queryParameters: {'q': query},
    );
    final list = _extractList(response.data);
    return list
        .map((e) => ItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Paginated product search optionally filtered by product category
  /// (`category_value_id`) and/or brand — the same filters the web item
  /// master uses. Used by task assignment (pick products within a
  /// category/brand) and task detail ("products in scope"). An empty [query]
  /// is allowed here (lists the whole filtered scope, one page at a time).
  Future<PagedResult<ItemModel>> searchScoped({
    String query = '',
    String? categoryValueId,
    String? brandId,
    int page = 1,
    int perPage = 20,
  }) async {
    final response = await _apiClient.request(
      ApiConstants.itemsSearch,
      queryParameters: {
        if (query.trim().isNotEmpty) 'q': query.trim(),
        if (categoryValueId != null) 'category_value_id': categoryValueId,
        if (brandId != null) 'brand_id': brandId,
        'page': page,
        'per_page': perPage,
      },
    );
    return PagedResult.fromLaravel(response.data, ItemModel.fromJson);
  }

  Future<ItemModel> byBarcode(String code) async {
    final response = await _apiClient.request(ApiConstants.itemBarcode(code));
    final data = response.data is Map && response.data['data'] != null
        ? response.data['data']
        : response.data;
    return ItemModel.fromJson(data as Map<String, dynamic>);
  }

  /// Returns batches for an item at a branch. The caller's role determines
  /// whether `remaining_qty` is present on each [BatchModel] — this repository
  /// does not filter or guess; it simply reflects what the server sent.
  Future<List<BatchModel>> batches({
    required String itemId,
    required String branchId,
  }) async {
    final response = await _apiClient.request(
      ApiConstants.itemBatches(itemId),
      queryParameters: {'branch_id': branchId},
    );
    final list = _extractList(response.data);
    return list
        .map((e) => BatchModel.fromJson(e as Map<String, dynamic>))
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
