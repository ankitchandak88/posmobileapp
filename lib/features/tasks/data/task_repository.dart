import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/models.dart';

/// One product (optionally pinned to a specific batch) selected when
/// assigning a task — see [TaskRepository.createBody].
typedef TaskItemSelection = ({String itemId, String? batchNo});

/// Live client for the `/v1/tasks` contract (see
/// URBANPETS_API_DOCUMENTATION.md). Wired directly to the real Laravel
/// endpoints — callers (see lib/features/tasks/state/task_providers.dart)
/// let failures propagate as errors rather than falling back to mock data.
class TaskRepository {
  TaskRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  static List _list(dynamic body) => (body is List)
      ? body
      : (body is Map ? (body['data'] as List? ?? []) : []);

  static Map<String, dynamic> _data(dynamic body) => Map<String, dynamic>.from(
    body is Map && body['data'] is Map ? body['data'] as Map : body as Map,
  );

  /// `GET /v1/tasks`. Staff: server returns only tasks assigned to them.
  /// Manager/Owner: every task in their accessible branch(es), optionally
  /// filtered by product category ([categoryValueId]) and/or [brandId].
  Future<List<TaskModel>> myTasks({
    String? categoryValueId,
    String? brandId,
    String? status,
  }) async {
    final response = await _apiClient.request(
      ApiConstants.tasks,
      queryParameters: {
        if (categoryValueId != null) 'category_value_id': categoryValueId,
        if (brandId != null) 'brand_id': brandId,
        if (status != null) 'status': status,
        'per_page': 100,
      },
    );
    return _list(response.data)
        .map((e) => TaskModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// `GET /v1/tasks/{id}` — includes branch/assignee/category/brand names and
  /// selected products. 403 unless assignee or branch-authorised.
  Future<TaskModel> detail(String id) async {
    final response = await _apiClient.request(ApiConstants.taskDetail(id));
    return TaskModel.fromJson(_data(response.data));
  }

  /// Body for `POST /v1/tasks`. Exposed for tests. [items] pairs an item id
  /// with an optional specific batch to count (the server accepts
  /// `items[].batch_no`) — most tasks scope by category/brand alone and
  /// leave this empty.
  static Map<String, dynamic> createBody({
    required String branchId,
    required String title,
    String? section,
    String? categoryValueId,
    String? brandId,
    List<String> categoryValueIds = const [],
    List<String> brandIds = const [],
    String? assignedTo,
    List<String> assignedToIds = const [],
    DateTime? dueDate,
    String priority = 'normal',
    List<TaskItemSelection> items = const [],
  }) => {
    'branch_id': branchId,
    'title': title,
    'section': section,
    'category_value_id': categoryValueId,
    'brand_id': brandId,
    if (categoryValueIds.isNotEmpty) 'category_value_ids': categoryValueIds,
    if (brandIds.isNotEmpty) 'brand_ids': brandIds,
    if (assignedToIds.isNotEmpty) 'assigned_to_ids': assignedToIds,
    if (assignedTo != null && assignedTo.isNotEmpty) 'assigned_to': assignedTo,
    'due_date': dueDate == null
        ? null
        : '${dueDate.year.toString().padLeft(4, '0')}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}',
    'priority': priority,
    if (items.isNotEmpty)
      'items': [
        for (final i in items)
          {'item_id': i.itemId, if (i.batchNo != null) 'batch_no': i.batchNo},
      ],
  };

  /// `POST /v1/tasks` (Manager/Owner — `stock-verification.assign-task`).
  /// When category/brand scope is set together with [items], the server
  /// rejects (422) any product outside the UNION of every selected
  /// category/brand.
  Future<TaskModel> create({
    required String branchId,
    required String title,
    String? section,
    String? categoryValueId,
    String? brandId,
    List<String> categoryValueIds = const [],
    List<String> brandIds = const [],
    String? assignedTo,
    List<String> assignedToIds = const [],
    DateTime? dueDate,
    String priority = 'normal',
    List<TaskItemSelection> items = const [],
  }) async {
    final response = await _apiClient.request(
      ApiConstants.tasks,
      method: 'POST',
      data: createBody(
        branchId: branchId,
        title: title,
        section: section,
        categoryValueId: categoryValueId,
        brandId: brandId,
        categoryValueIds: categoryValueIds,
        brandIds: brandIds,
        assignedTo: assignedTo,
        assignedToIds: assignedToIds,
        dueDate: dueDate,
        priority: priority,
        items: items,
      ),
    );
    return TaskModel.fromJson(_data(response.data));
  }

  /// `PATCH /v1/tasks/{task}/status`. Valid transitions are enforced
  /// server-side (`pending->in_progress`/`in_progress->completed` by the
  /// assignee; `pending->cancelled`/`in_progress->cancelled` by a
  /// Manager/Owner) — an invalid transition is `422`, a structurally valid
  /// one performed by the wrong actor is `403`. Both propagate as an
  /// [ApiException] via [ApiClient] for the caller to surface.
  Future<TaskModel> updateStatus(String taskId, String status) async {
    final response = await _apiClient.request(
      ApiConstants.taskStatus(taskId),
      method: 'PATCH',
      data: {'status': status},
    );
    return TaskModel.fromJson(_data(response.data));
  }

  /// `GET /v1/categories` — product categories (POS "CATEGORY" values).
  Future<List<CategoryModel>> categories() async {
    final response = await _apiClient.request(ApiConstants.categories);
    return _list(response.data)
        .map((e) => CategoryModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// `GET /v1/brands` — active brands (optionally filtered by category).
  Future<List<BrandModel>> brands({String? categoryValueId}) async {
    final response = await _apiClient.request(
      ApiConstants.brands,
      queryParameters: {
        if (categoryValueId != null && categoryValueId.isNotEmpty)
          'category_value_id': categoryValueId,
      },
    );
    return _list(response.data)
        .map((e) => BrandModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// `GET /v1/tasks/assignees?branch_id=` (Manager/Owner only).
  Future<List<AssigneeModel>> assignees(String branchId) async {
    final response = await _apiClient.request(
      ApiConstants.taskAssignees,
      queryParameters: {'branch_id': branchId},
    );
    return _list(response.data)
        .map((e) => AssigneeModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
