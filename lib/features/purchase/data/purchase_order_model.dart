import '../../../core/utils/parse_helpers.dart';

class PurchaseOrderModel {
  const PurchaseOrderModel({
    required this.id,
    required this.poNumber,
    this.poDate,
    required this.supplierId,
    required this.supplierName,
    this.supplierPhone,
    required this.branchId,
    this.branchName,
    this.status = 'Open',
    this.totalQty = 0,
    this.totalItems = 0,
    this.totalAmount = 0,
    this.remarks,
    this.items = const [],
  });

  final String id;
  final String poNumber;
  final String? poDate;
  final String supplierId;
  final String supplierName;
  final String? supplierPhone;
  final String branchId;
  final String? branchName;
  final String status;
  final num totalQty;
  final int totalItems;
  final num totalAmount;
  final String? remarks;
  final List<PurchaseOrderItemModel> items;

  factory PurchaseOrderModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final parsedItems = rawItems is List
        ? rawItems
            .map((e) => PurchaseOrderItemModel.fromJson(e as Map<String, dynamic>))
            .toList()
        : <PurchaseOrderItemModel>[];

    return PurchaseOrderModel(
      id: json['id'].toString(),
      poNumber: json['po_number'] as String? ?? 'PO-${json['id']}',
      poDate: json['po_date'] as String?,
      supplierId: json['supplier_id']?.toString() ?? '',
      supplierName: json['supplier_name'] as String? ?? 'Unknown Supplier',
      supplierPhone: json['supplier_phone'] as String?,
      branchId: json['branch_id']?.toString() ?? '',
      branchName: json['branch_name'] as String?,
      status: json['status'] as String? ?? 'Open',
      totalQty: parseNum(json['total_qty']) ?? 0,
      totalItems: parseInt(json['total_items']) ?? parsedItems.length,
      totalAmount: parseNum(json['total_amount']) ?? 0,
      remarks: json['remarks'] as String?,
      items: parsedItems,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'po_number': poNumber,
        if (poDate != null) 'po_date': poDate,
        'supplier_id': supplierId,
        'supplier_name': supplierName,
        if (supplierPhone != null) 'supplier_phone': supplierPhone,
        'branch_id': branchId,
        if (branchName != null) 'branch_name': branchName,
        'status': status,
        'total_qty': totalQty,
        'total_items': totalItems,
        'total_amount': totalAmount,
        if (remarks != null) 'remarks': remarks,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

class PurchaseOrderItemModel {
  const PurchaseOrderItemModel({
    required this.id,
    required this.poItemId,
    required this.itemId,
    required this.name,
    this.itemCode,
    this.barcode,
    this.orderedQty = 0,
    this.receivedQty = 0,
    this.costPrice = 0,
    this.mrp = 0,
  });

  final String id;
  final String poItemId;
  final String itemId;
  final String name;
  final String? itemCode;
  final String? barcode;
  final num orderedQty;
  final num receivedQty;
  final num costPrice;
  final num mrp;

  factory PurchaseOrderItemModel.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderItemModel(
      id: json['id']?.toString() ?? json['po_item_id']?.toString() ?? '',
      poItemId: json['po_item_id']?.toString() ?? json['id']?.toString() ?? '',
      itemId: json['item_id']?.toString() ?? '',
      name: json['name'] as String? ?? json['item_name'] as String? ?? 'Unknown Item',
      itemCode: json['item_code'] as String?,
      barcode: json['barcode'] as String?,
      orderedQty: parseNum(json['ordered_qty']) ?? parseNum(json['qty']) ?? 0,
      receivedQty: parseNum(json['received_qty']) ?? 0,
      costPrice: parseNum(json['cost_price']) ?? 0,
      mrp: parseNum(json['mrp']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'po_item_id': poItemId,
        'item_id': itemId,
        'name': name,
        if (itemCode != null) 'item_code': itemCode,
        if (barcode != null) 'barcode': barcode,
        'ordered_qty': orderedQty,
        'received_qty': receivedQty,
        'cost_price': costPrice,
        'mrp': mrp,
      };
}
