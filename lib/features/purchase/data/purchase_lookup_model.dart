import '../../../core/utils/parse_helpers.dart';

class PurchaseItemInfo {
  const PurchaseItemInfo({
    required this.id,
    required this.name,
    required this.sku,
    this.barcode,
    this.brandName,
    this.categoryName,
  });

  final String id;
  final String name;
  final String sku;
  final String? barcode;
  final String? brandName;
  final String? categoryName;

  factory PurchaseItemInfo.fromJson(Map<String, dynamic> json) {
    return PurchaseItemInfo(
      id: json['id'].toString(),
      name: json['name'] as String? ?? 'Unknown item',
      sku: json['item_code'] as String? ?? '',
      barcode: json['ean_upc_code'] as String?,
      brandName: json['brand_name'] as String?,
      categoryName: json['category_name'] as String?,
    );
  }
}

class PurchasePricing {
  const PurchasePricing({
    required this.costPrice,
    required this.landingCost,
    required this.mrp,
    required this.sellPrice,
    required this.marginPercent,
  });

  final double costPrice;
  final double landingCost;
  final double mrp;
  final double sellPrice;
  final double marginPercent;

  factory PurchasePricing.fromJson(Map<String, dynamic> json) {
    return PurchasePricing(
      costPrice: parseDouble(json['cost_price']) ?? 0.0,
      landingCost: parseDouble(json['landing_cost']) ?? 0.0,
      mrp: parseDouble(json['mrp']) ?? 0.0,
      sellPrice: parseDouble(json['sell_price']) ?? 0.0,
      marginPercent: parseDouble(json['margin_percent']) ?? 0.0,
    );
  }
}

class PurchaseSupplier {
  const PurchaseSupplier({
    required this.id,
    required this.name,
    this.mobile,
    this.gstin,
    this.email,
  });

  final int id;
  final String name;
  final String? mobile;
  final String? gstin;
  final String? email;

  factory PurchaseSupplier.fromJson(Map<String, dynamic> json) {
    return PurchaseSupplier(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] as String? ?? 'Unknown Supplier',
      mobile: json['mobile'] as String?,
      gstin: json['gstin'] as String?,
      email: json['email'] as String?,
    );
  }
}

class PurchaseInventory {
  const PurchaseInventory({
    required this.branchId,
    required this.currentStock,
    this.batchCount = 0,
  });

  final int branchId;
  final double currentStock;
  final int batchCount;

  factory PurchaseInventory.fromJson(Map<String, dynamic> json) {
    return PurchaseInventory(
      branchId: json['branch_id'] is int
          ? json['branch_id'] as int
          : int.tryParse(json['branch_id'].toString()) ?? 1,
      currentStock: parseDouble(json['current_stock']) ?? 0.0,
      batchCount: parseInt(json['batch_count']) ?? 0,
    );
  }
}

class PurchaseInwardLine {
  const PurchaseInwardLine({
    required this.id,
    required this.invoiceNumber,
    this.invoiceDate,
    required this.supplierName,
    this.branchName,
    required this.costPrice,
    required this.qty,
    this.freeQty = 0.0,
    required this.netAmount,
    this.batchNo,
    this.expDate,
  });

  final int id;
  final String invoiceNumber;
  final String? invoiceDate;
  final String supplierName;
  final String? branchName;
  final double costPrice;
  final double qty;
  final double freeQty;
  final double netAmount;
  final String? batchNo;
  final String? expDate;

  factory PurchaseInwardLine.fromJson(Map<String, dynamic> json) {
    return PurchaseInwardLine(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id'].toString()) ?? 0,
      invoiceNumber: json['invoice_number'] as String? ?? '-',
      invoiceDate: json['invoice_date'] as String?,
      supplierName: json['supplier_name'] as String? ?? '-',
      branchName: json['branch_name'] as String?,
      costPrice: parseDouble(json['cost_price']) ?? 0.0,
      qty: parseDouble(json['qty']) ?? 0.0,
      freeQty: parseDouble(json['free_qty']) ?? 0.0,
      netAmount: parseDouble(json['net_amount']) ?? 0.0,
      batchNo: json['batch_no'] as String?,
      expDate: json['exp_date'] as String?,
    );
  }
}

class PurchaseLookupModel {
  const PurchaseLookupModel({
    required this.item,
    required this.pricing,
    this.supplier,
    required this.inventory,
    this.recentInwards = const [],
  });

  final PurchaseItemInfo item;
  final PurchasePricing pricing;
  final PurchaseSupplier? supplier;
  final PurchaseInventory inventory;
  final List<PurchaseInwardLine> recentInwards;

  factory PurchaseLookupModel.fromJson(Map<String, dynamic> json) {
    final itemMap = json['item'] as Map<String, dynamic>? ?? {};
    final pricingMap = json['pricing'] as Map<String, dynamic>? ?? {};
    final supplierMap = json['supplier'] as Map<String, dynamic>?;
    final inventoryMap = json['inventory'] as Map<String, dynamic>? ?? {};
    final inwardsList = json['recent_inwards'] as List<dynamic>? ?? [];

    return PurchaseLookupModel(
      item: PurchaseItemInfo.fromJson(itemMap),
      pricing: PurchasePricing.fromJson(pricingMap),
      supplier: supplierMap != null ? PurchaseSupplier.fromJson(supplierMap) : null,
      inventory: PurchaseInventory.fromJson(inventoryMap),
      recentInwards: inwardsList
          .whereType<Map<String, dynamic>>()
          .map(PurchaseInwardLine.fromJson)
          .toList(),
    );
  }
}

