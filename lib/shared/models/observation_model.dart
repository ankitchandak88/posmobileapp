/// inventory_observations row (see URBANPETS_DATABASE_AND_WORKFLOW.md §3).
///
/// IMPORTANT: `system_qty_snapshot` is documented as "never returned to
/// staff in API responses". This model keeps it nullable and the staff-facing
/// submission screens never read or display it. Only the manager review
/// queue (`ObservationModel.variance`) is allowed to use it.
class ObservationModel {
  ObservationModel({
    required this.id,
    required this.type,
    this.taskId,
    required this.itemId,
    this.itemName,
    required this.branchId,
    this.batchNo,
    this.expDateObserved,
    this.physicalQty,
    this.remarks,
    this.photoPath,
    required this.idempotencyKey,
    this.systemQtySnapshot,
    required this.status,
    this.parentObservationId,
    this.approvedQty,
    this.actualAdjustmentQty,
    this.reviewRemarks,
    this.submittedBy,
    this.reviewedBy,
    this.createdAt,
    this.branchName,
    this.submittedByName,
    this.reviewedByName,
    this.itemCode,
    this.reviewedAt,
    this.recounts = const [],
    this.parentObservation,
    this.supplierId,
    this.supplierName,
  });

  final String id;
  final String type; // stock_count | expiry_check
  final String? taskId;
  final String itemId;
  final String? itemName;
  final String branchId;
  final String? batchNo;
  final DateTime? expDateObserved;
  final num? physicalQty;
  final String? remarks;
  final String? photoPath;
  final String idempotencyKey;

  /// Manager/review-only field. Never set from a staff-facing response.
  final num? systemQtySnapshot;

  final String status; // pending | approved | rejected | recount_requested
  final String? parentObservationId;
  final num? approvedQty;
  final num? actualAdjustmentQty;
  final String? reviewRemarks;
  final String? submittedBy;
  final String? reviewedBy;
  final DateTime? createdAt;

  /// Only populated by the Manager/Owner audit endpoint
  /// (`GET /v1/observations` — see [ObservationRepository.history]).
  final String? branchName;
  final String? submittedByName;
  final String? reviewedByName;
  final String? itemCode;
  final String? supplierId;
  final String? supplierName;
  final DateTime? reviewedAt;

  /// Prior recount attempts spawned from this observation. Only populated by
  /// `GET /v1/observations/{id}` (see [ObservationRepository.show]) — list
  /// endpoints never embed this chain.
  final List<ObservationModel> recounts;

  /// The observation this one was resubmitted from (if it is itself a
  /// recount), from the same `show()` endpoint. Null for the original.
  final ObservationModel? parentObservation;

  /// physical_qty - system_qty_snapshot, only computable when both are
  /// present (reviewer context). Returns null otherwise — UI must render
  /// that as "-", never as 0.
  num? get variance {
    if (physicalQty == null || systemQtySnapshot == null) return null;
    return physicalQty! - systemQtySnapshot!;
  }

  /// Laravel serializes `decimal:N`-cast model attributes (e.g.
  /// `physical_qty`, `system_qty_snapshot`, `approved_qty`,
  /// `actual_adjustment_qty`) as JSON STRINGS (e.g. `"10.000"`), not JSON
  /// numbers — verified against the real `/v1/observations*` responses
  /// during Phase 11 integration. A plain `as num?` cast throws at runtime
  /// on a String, so every quantity field here is parsed through this
  /// helper instead.
  static num? _num(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    return null;
  }

  factory ObservationModel.fromJson(Map<String, dynamic> json) {
    return ObservationModel(
      id: json['id'].toString(),
      type: json['type'] as String? ?? 'stock_count',
      taskId: json['task_id']?.toString(),
      itemId: json['item_id'].toString(),
      itemName: json['item_name'] as String?,
      branchId: json['branch_id'].toString(),
      batchNo: json['batch_no'] as String?,
      expDateObserved: json['exp_date_observed'] != null
          ? DateTime.tryParse(json['exp_date_observed'] as String)
          : null,
      physicalQty: _num(json['physical_qty']),
      remarks: json['remarks'] as String?,
      photoPath: json['photo_path'] as String?,
      idempotencyKey: json['idempotency_key'] as String? ?? '',
      systemQtySnapshot: _num(json['system_qty_snapshot']),
      status: json['status'] as String? ?? 'pending',
      parentObservationId: json['parent_observation_id']?.toString(),
      approvedQty: _num(json['approved_qty']),
      actualAdjustmentQty: _num(json['actual_adjustment_qty']),
      reviewRemarks: json['review_remarks'] as String?,
      submittedBy: json['submitted_by']?.toString(),
      reviewedBy: json['reviewed_by']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      branchName: json['branch_name'] as String?,
      supplierId: json['supplier_id']?.toString(),
      supplierName: json['supplier_name'] as String?,
      submittedByName: json['submitted_by_name'] as String?,
      reviewedByName: json['reviewed_by_name'] as String?,
      itemCode: json['item_code'] as String?,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.tryParse(json['reviewed_at'] as String)
          : null,
      recounts: json['recounts'] is List
          ? (json['recounts'] as List)
                .map((e) => ObservationModel.fromJson(e as Map<String, dynamic>))
                .toList()
          : const [],
      parentObservation: json['parent_observation'] is Map
          ? ObservationModel.fromJson(
              json['parent_observation'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'task_id': taskId,
    'item_id': itemId,
    'branch_id': branchId,
    'batch_no': batchNo,
    'exp_date_observed': expDateObserved?.toIso8601String(),
    'physical_qty': physicalQty,
    'remarks': remarks,
    'photo_path': photoPath,
    'idempotency_key': idempotencyKey,
    'status': status,
    if (supplierId != null) 'supplier_id': supplierId,
    if (supplierName != null) 'supplier_name': supplierName,
  };
}
