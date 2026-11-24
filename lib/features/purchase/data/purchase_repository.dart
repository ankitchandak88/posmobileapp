import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/reference_models.dart';
import 'purchase_lookup_model.dart';

class PurchaseRepository {
  PurchaseRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<PurchaseLookupModel> lookupItem(String code, {String? branchId}) async {
    final response = await _apiClient.request(
      ApiConstants.purchaseItemLookup(Uri.encodeComponent(code)),
      queryParameters: {
        if (branchId != null) 'branch_id': branchId,
      },
    );

    final raw = response.data;
    final data = raw is Map && raw['data'] != null ? raw['data'] as Map<String, dynamic> : raw as Map<String, dynamic>;
    return PurchaseLookupModel.fromJson(data);
  }

  Future<List<SupplierModel>> suppliers({String? search}) async {
    final response = await _apiClient.request(
      ApiConstants.suppliers,
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );

    final raw = response.data;
    final list = raw is Map && raw['data'] != null
        ? raw['data'] as List
        : (raw is List ? raw : []);
    return list
        .map((e) => SupplierModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
