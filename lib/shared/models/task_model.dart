/// stock_count_tasks row (see URBANPETS_DATABASE_AND_WORKFLOW.md §3).
///
/// Nested relation objects (`branch`, `assignee`, `category_value`, `brand`,
/// `items[].item`) are eager-loaded by `TaskController` on both the list and
/// detail endpoints; every one of them is optional here so an older/smaller
/// payload still parses.
class TaskModel {
  TaskModel({
    required this.id,
    required this.branchId,
    required this.title,
    this.section,
    this.categoryId,
    this.categoryValueId,
    this.categoryName,
    this.brandId,
    this.brandName,
    this.branchName,
    required this.assignedTo,
    this.assigneeName,
    this.assignerName,
    this.dueDate,
    required this.priority,
    required this.status,
    this.items = const [],
    this.observedItemIds = const {},
    this.observationCount = 0,
  });

  final String id;
  final String branchId;
  final String title;
  final String? section;

  /// Legacy item_categories (category HEAD) id — kept for compatibility.
  final String? categoryId;

  /// Product category (`items.category_value_id`) the task is scoped to.
  final String? categoryValueId;
  final String? categoryName;
  final String? brandId;
  final String? brandName;
  final String? branchName;
  final String assignedTo;
  final String? assigneeName;
  final String? assignerName;
  final DateTime? dueDate;
  final String priority; // low | normal | high
  final String status; // pending | in_progress | completed | cancelled
  final List<TaskItemModel> items;

  /// Distinct products with at least one observation on this task (from the
  /// detail endpoint's `observations`; empty on list rows). Drives the
  /// task-progress indicator.
  final Set<String> observedItemIds;
  final int observationCount;

  /// True when the task is scoped by category and/or brand.
  bool get hasCategoryOrBrandScope =>
      categoryValueId != null || brandId != null;

  static String? _name(dynamic relation) =>
      relation is Map ? relation['name'] as String? : null;

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final rawObservations = json['observations'];
    final observations = rawObservations is List
        ? rawObservations.whereType<Map>().toList()
        : const <Map>[];
    return TaskModel(
      id: json['id'].toString(),
      branchId: json['branch_id'].toString(),
      title: json['title'] as String? ?? 'Untitled task',
      section: json['section'] as String?,
      categoryId: json['category_id']?.toString(),
      categoryValueId: json['category_value_id']?.toString(),
      categoryName: _name(json['category_value']),
      brandId: json['brand_id']?.toString(),
      brandName: _name(json['brand']),
      branchName: _name(json['branch']),
      assignedTo: json['assigned_to'].toString(),
      assigneeName: _name(json['assignee']),
      assignerName: _name(json['assigner']),
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'] as String)
          : null,
      priority: json['priority'] as String? ?? 'normal',
      status: json['status'] as String? ?? 'pending',
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (e) => TaskItemModel.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList()
          : const [],
      observedItemIds: {
        for (final o in observations)
          if (o['item_id'] != null) o['item_id'].toString(),
      },
      observationCount: observations.length,
    );
  }
}

/// stock_count_task_items row — an explicitly selected product/batch.
class TaskItemModel {
  const TaskItemModel({
    this.itemId,
    this.itemName,
    this.itemCode,
    this.batchNo,
  });

  final String? itemId;
  final String? itemName;
  final String? itemCode;
  final String? batchNo;

  factory TaskItemModel.fromJson(Map<String, dynamic> json) {
    final item = json['item'];
    return TaskItemModel(
      itemId: json['item_id']?.toString(),
      itemName: item is Map ? item['name'] as String? : null,
      itemCode: item is Map ? item['item_code'] as String? : null,
      batchNo: json['batch_no'] as String?,
    );
  }
}
