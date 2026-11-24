import '../../core/utils/parse_helpers.dart';

/// Product item returned by /items/search and /items/barcode/{code}.
///
/// NOTE: the real Laravel response (see `ItemController::search()` /
/// `byBarcode()`) uses `item_code` and `ean_upc_code`, not the originally
/// assumed `sku` / `barcode` keys — there is no `image_url` or
/// `category_name` in either response at all. Corrected during Phase 11
/// integration; [imageUrl]/[categoryName] are kept as always-null optional
/// fields since no endpoint currently supplies them.
class ItemModel {
  ItemModel({
    required this.id,
    required this.name,
    required this.sku,
    this.barcode,
    this.mrp,
    this.imageUrl,
    this.categoryName,
    this.brandId,
    this.categoryValueId,
  });

  final String id;
  final String name;
  final String sku;
  final String? barcode;
  final num? mrp;
  final String? imageUrl;
  final String? categoryName;

  /// items.brand_id / items.category_value_id (present on /items/search
  /// rows) — used to keep a task's selected products inside its scope.
  final String? brandId;
  final String? categoryValueId;

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    return ItemModel(
      id: json['id'].toString(),
      name: json['name'] as String? ?? 'Unknown item',
      sku: json['item_code'] as String? ?? '',
      barcode: json['ean_upc_code'] as String?,
      mrp: parseNum(json['mrp']),
      imageUrl: json['image_url'] as String?,
      categoryName: json['category_name'] as String?,
      brandId: json['brand_id']?.toString(),
      categoryValueId: json['category_value_id']?.toString(),
    );
  }
}

/// Batch row from GET /items/{item}/batches?branch_id=.
///
/// CRITICAL (blind counting): for a Staff-role caller, `remaining_qty` is
/// OMITTED entirely from the server response (`ItemController::batches()`
/// calls `unset($batch['remaining_qty'])` for a blind-staff caller) — not
/// merely null. This model therefore treats it as nullable/absent via
/// `containsKey`, and UI code for the staff-facing blind-count screen must
/// never read [systemQty].
///
/// NOTE: an earlier draft of this model assumed the key was named
/// `system_qty`; the real Laravel response (see
/// `app/Services/Inventory/BatchStockService.php` and
/// `app/Http/Controllers/Api/V1/ItemController.php`) uses `remaining_qty`.
/// Corrected during Phase 11 integration.
class BatchModel {
  BatchModel({
    required this.batchNo,
    this.expDate,
    this.systemQty,
    this.hasSystemQty = false,
    this.rackSection,
  });

  final String batchNo;
  final DateTime? expDate;

  /// Only meaningful when [hasSystemQty] is true (Manager/Owner response).
  final num? systemQty;

  /// True only if the server response actually included the `remaining_qty`
  /// key. Staff responses must have this false.
  final bool hasSystemQty;

  final String? rackSection;

  factory BatchModel.fromJson(Map<String, dynamic> json) {
    final hasKey = json.containsKey('remaining_qty');
    return BatchModel(
      batchNo: json['batch_no'] as String? ?? '-',
      expDate: json['exp_date'] != null
          ? DateTime.tryParse(json['exp_date'] as String)
          : null,
      systemQty: hasKey ? parseNum(json['remaining_qty']) : null,
      hasSystemQty: hasKey && json['remaining_qty'] != null,
      rackSection: json['rack_section'] as String?,
    );
  }
}
