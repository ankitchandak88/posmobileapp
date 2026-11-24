import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/models.dart';

/// `barcode_mapping_requests` row as returned by
/// `GET /v1/barcode-mapping-requests` (with eager-loaded suggested item,
/// branch and submitter).
class BarcodeMappingRequestModel {
  const BarcodeMappingRequestModel({
    required this.id,
    required this.scannedBarcode,
    this.suggestedItemId,
    this.suggestedItemName,
    this.suggestedItemCurrentBarcode,
    required this.branchId,
    this.branchName,
    required this.status,
    this.submittedByName,
    this.remarks,
    this.createdAt,
  });

  final String id;
  final String scannedBarcode;
  final String? suggestedItemId;
  final String? suggestedItemName;

  /// The suggested item's CURRENT `ean_upc_code` (if any) — lets the
  /// reviewer see up-front that approving would replace an existing barcode.
  final String? suggestedItemCurrentBarcode;
  final String branchId;
  final String? branchName;
  final String status; // pending | approved | rejected
  final String? submittedByName;
  final String? remarks;
  final DateTime? createdAt;

  factory BarcodeMappingRequestModel.fromJson(Map<String, dynamic> json) {
    final item = json['suggested_item'];
    final branch = json['branch'];
    final submitter = json['submitter'];
    return BarcodeMappingRequestModel(
      id: json['id'].toString(),
      scannedBarcode: json['scanned_barcode'] as String? ?? '',
      suggestedItemId: json['suggested_item_id']?.toString(),
      suggestedItemName: item is Map ? item['name'] as String? : null,
      suggestedItemCurrentBarcode: item is Map
          ? item['ean_upc_code'] as String?
          : null,
      branchId: json['branch_id'].toString(),
      branchName: branch is Map ? branch['name'] as String? : null,
      status: json['status'] as String? ?? 'pending',
      submittedByName: submitter is Map ? submitter['name'] as String? : null,
      remarks: json['remarks'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

class BarcodeMappingRepository {
  BarcodeMappingRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<void> submitRequest({
    required String scannedBarcode,
    String? suggestedItemId,
    required String branchId,
    String? remarks,
  }) async {
    await _apiClient.request(
      ApiConstants.barcodeMappingRequests,
      method: 'POST',
      data: {
        'scanned_barcode': scannedBarcode,
        'suggested_item_id': suggestedItemId,
        'branch_id': branchId,
        'remarks': remarks,
      },
    );
  }

  /// Manager/Owner review queue (`barcode-mapping.review`), branch-scoped
  /// server-side.
  Future<PagedResult<BarcodeMappingRequestModel>> list({
    String status = 'pending',
    int page = 1,
  }) async {
    final response = await _apiClient.request(
      ApiConstants.barcodeMappingRequests,
      queryParameters: {'status': status, 'page': page, 'per_page': 50},
    );
    return PagedResult.fromLaravel(
      response.data,
      BarcodeMappingRequestModel.fromJson,
    );
  }

  /// Approves the mapping. The server refuses (422) to overwrite an item's
  /// existing, different barcode unless [force] is true — callers must only
  /// pass force after an explicit user confirmation.
  Future<void> approve(
    String id, {
    String? itemId,
    bool force = false,
    String? remarks,
  }) async {
    await _apiClient.request(
      ApiConstants.barcodeMappingApprove(id),
      method: 'POST',
      data: {'item_id': itemId, if (force) 'force': true, 'remarks': remarks},
    );
  }

  Future<void> reject(String id, {required String remarks}) async {
    await _apiClient.request(
      ApiConstants.barcodeMappingReject(id),
      method: 'POST',
      data: {'remarks': remarks},
    );
  }
}
