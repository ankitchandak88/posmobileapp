/// Product category as the POS defines it: an `item_category_values` row
/// under the "CATEGORY" head (`items.category_value_id`). Returned by
/// `GET /v1/categories`.
class CategoryModel {
  const CategoryModel({required this.id, required this.name});

  final String id;
  final String name;

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
    id: json['id'].toString(),
    name: json['name'] as String? ?? 'Category',
  );
}

/// `brands` row (`items.brand_id`). Returned by `GET /v1/brands`.
class BrandModel {
  const BrandModel({required this.id, required this.name});

  final String id;
  final String name;

  factory BrandModel.fromJson(Map<String, dynamic> json) => BrandModel(
    id: json['id'].toString(),
    name: json['name'] as String? ?? 'Brand',
  );
}

/// A user a Manager/Owner may assign a count task to, from
/// `GET /v1/tasks/assignees?branch_id=` (only id/name/role are exposed).
class AssigneeModel {
  const AssigneeModel({required this.id, required this.name, this.role});

  final String id;
  final String name;
  final String? role;

  factory AssigneeModel.fromJson(Map<String, dynamic> json) => AssigneeModel(
    id: json['id'].toString(),
    name: json['name'] as String? ?? 'User',
    role: json['role'] as String?,
  );
}

/// Supplier row (`suppliers.id`). Returned by `GET /v1/suppliers`.
class SupplierModel {
  const SupplierModel({
    required this.id,
    required this.name,
    this.phone,
    this.mobile,
  });

  final String id;
  final String name;
  final String? phone;
  final String? mobile;

  factory SupplierModel.fromJson(Map<String, dynamic> json) => SupplierModel(
    id: json['id'].toString(),
    name: json['name'] as String? ?? 'Supplier',
    phone: json['phone'] as String?,
    mobile: json['mobile'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (phone != null) 'phone': phone,
    if (mobile != null) 'mobile': mobile,
  };
}
