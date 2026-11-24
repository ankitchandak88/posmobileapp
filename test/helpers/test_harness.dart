import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:urban_pets_verify/core/network/api_client.dart';
import 'package:urban_pets_verify/core/storage/quick_unlock_service.dart';
import 'package:urban_pets_verify/core/storage/secure_token_storage.dart';
import 'package:urban_pets_verify/core/theme/app_theme.dart';
import 'package:urban_pets_verify/features/auth/data/auth_repository.dart';
import 'package:urban_pets_verify/features/auth/data/user_model.dart';
import 'package:urban_pets_verify/features/auth/state/auth_providers.dart';
import 'package:urban_pets_verify/features/dashboard/data/branch_repository.dart';
import 'package:urban_pets_verify/features/dashboard/state/dashboard_providers.dart';
import 'package:urban_pets_verify/features/review/data/observation_repository.dart';
import 'package:urban_pets_verify/features/review/state/review_providers.dart';
import 'package:urban_pets_verify/features/rider/data/rider_order_model.dart';
import 'package:urban_pets_verify/features/rider/data/rider_order_repository.dart';
import 'package:urban_pets_verify/features/rider/data/vehicle_model.dart';
import 'package:urban_pets_verify/features/scanner/data/item_repository.dart';
import 'package:urban_pets_verify/features/scanner/state/scanner_providers.dart';
import 'package:urban_pets_verify/features/tasks/data/task_repository.dart';
import 'package:urban_pets_verify/features/tasks/state/task_providers.dart';
import 'package:urban_pets_verify/shared/models/models.dart';

// ---------------------------------------------------------------------------
// Users
// ---------------------------------------------------------------------------

final staffUser = UserModel(
  id: '11',
  name: 'Alice Staff',
  email: 'alice@test.local',
  role: 'Staff',
  branchId: '1',
);

final managerUser = UserModel(
  id: '21',
  name: 'Mona Manager',
  email: 'mona@test.local',
  role: 'Manager',
  branchId: '1',
);

final riderUser = UserModel(
  id: '31',
  name: 'Rahul Rider',
  email: 'rider@test.local',
  role: 'rider',
  branchId: '1',
);

// ---------------------------------------------------------------------------
// Infrastructure fakes (no platform channels, no network)
// ---------------------------------------------------------------------------

class FakeTokenStorage extends SecureTokenStorage {
  @override
  Future<String?> readToken() async => null;
  @override
  Future<String?> readTokenForMode(String mode) async => null;
  @override
  Future<String?> readUserJson() async => null;
  @override
  Future<String?> readUserJsonForMode(String mode) async => null;
  @override
  Future<void> saveToken(String token) async {}
  @override
  Future<void> saveTokenForMode(String token, String mode) async {}
  @override
  Future<void> saveUserJson(String userJson) async {}
  @override
  Future<void> saveUserJsonForMode(String userJson, String mode) async {}
  @override
  Future<bool> hasStaffSession() async => false;
  @override
  Future<bool> hasRiderSession() async => false;
  @override
  Future<void> clearMode(String mode) async {}
  @override
  Future<void> clear() async {}

  // Quick-unlock is off by default in widget tests (no platform secure
  // storage available) — individual tests that need it on should fake
  // QuickUnlockService itself rather than relying on this storage.
  @override
  Future<void> saveQuickUnlockMode(String? mode) async {}
  @override
  Future<String?> readQuickUnlockMode() async => null;
  @override
  Future<void> savePin({required String hash, required String salt}) async {}
  @override
  Future<String?> readPinHash() async => null;
  @override
  Future<String?> readPinSalt() async => null;
  @override
  Future<int> readFailedPinAttempts() async => 0;
  @override
  Future<void> saveFailedPinAttempts(int attempts) async {}
  @override
  Future<void> clearFailedPinAttempts() async {}
  @override
  Future<void> clearQuickUnlock() async {}
}

/// Biometrics are never supported in the widget-test harness (no platform
/// implementation) — tests that need the biometric path fake this directly.
class FakeBiometricChecker implements BiometricChecker {
  FakeBiometricChecker({this.supported = false, this.authenticateResult = true});
  final bool supported;
  final bool authenticateResult;

  @override
  Future<bool> isSupported() async => supported;
  @override
  Future<bool> authenticate(String reason) async => authenticateResult;
}

/// An [ApiClient] whose Dio rejects every request — fakes below override
/// every repository method a test touches, so this only guards against an
/// unexpected real call.
ApiClient offlineApiClient() {
  final dio = Dio(BaseOptions(baseUrl: 'http://test.invalid/api/v1'))
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) => h.reject(
          DioException(requestOptions: o, message: 'no network in tests'),
        ),
      ),
    );
  return ApiClient(tokenStorage: FakeTokenStorage(), dio: dio);
}

class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository(this.user)
    : super(apiClient: offlineApiClient(), storage: FakeTokenStorage());

  final UserModel? user;

  @override
  Future<UserModel?> restoreSession() async => user;

  @override
  Future<void> logout({bool keepSavedAccounts = true}) async {}
}

/// Starts already authenticated (no async restore flash), so role-dependent
/// widgets/providers see the right user from their first build.
class FakeAuthController extends AuthController {
  FakeAuthController(UserModel user)
    : super(
        FakeAuthRepository(user),
        QuickUnlockService(
          storage: FakeTokenStorage(),
          checker: FakeBiometricChecker(),
        ),
      ) {
    state = AuthState(status: AuthStatus.authenticated, user: user);
  }
}

// ---------------------------------------------------------------------------
// Repository fakes
// ---------------------------------------------------------------------------

class HistoryCall {
  HistoryCall({
    required this.endpoint,
    this.branchId,
    this.dateFrom,
    this.dateTo,
    this.type,
    this.status,
    required this.page,
  });

  final String endpoint; // 'history' (cross-staff) | 'mine' (own-only)
  final String? branchId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? type;
  final String? status;
  final int page;
}

class SubmitCall {
  SubmitCall({
    required this.type,
    this.taskId,
    required this.itemId,
    required this.branchId,
    this.supplierId,
    this.batchNo,
    this.expDateObserved,
    this.physicalQty,
    this.remarks,
    required this.idempotencyKey,
  });

  final String type;
  final String? taskId;
  final String itemId;
  final String branchId;
  final String? supplierId;
  final String? batchNo;
  final DateTime? expDateObserved;
  final num? physicalQty;
  final String? remarks;
  final String idempotencyKey;
}

class FakeObservationRepository extends ObservationRepository {
  FakeObservationRepository() : super(apiClient: offlineApiClient());

  final historyCalls = <HistoryCall>[];
  final submitCalls = <SubmitCall>[];
  final reviewCalls = <String>[]; // e.g. 'approve:5:18', 'reject:5:bad'
  final showCalls = <String>[];

  /// Returned by [show]; defaults to echoing back the id with no extra
  /// recount/photo data unless a test sets this.
  ObservationModel Function(String id)? showHandler;

  /// Returned by [photoBytes]; defaults to a tiny non-empty byte list.
  List<int> Function(String id)? photoBytesHandler;

  @override
  Future<ObservationModel> show(String id) async {
    showCalls.add(id);
    return showHandler?.call(id) ??
        ObservationModel(
          id: id,
          type: 'stock_count',
          itemId: '1',
          branchId: '1',
          idempotencyKey: 'k',
          status: 'pending',
        );
  }

  @override
  Future<List<int>> photoBytes(String id) async =>
      photoBytesHandler?.call(id) ?? const [1, 2, 3];

  /// Returns the page for a call; default: one empty page.
  PagedResult<ObservationModel> Function(HistoryCall call)? historyHandler;

  /// Throw from here to simulate a failed history call.
  Object? historyError;

  /// Completer to hold a submit "in flight"; null = complete immediately.
  Completer<void>? submitGate;
  Object? submitError;

  PagedResult<ObservationModel> _page(HistoryCall call) {
    historyCalls.add(call);
    if (historyError != null) throw historyError!;
    return historyHandler?.call(call) ??
        const PagedResult(items: [], currentPage: 1, lastPage: 1, total: 0);
  }

  @override
  Future<PagedResult<ObservationModel>> history({
    String? branchId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? type,
    String? status,
    int page = 1,
    int perPage = 20,
  }) async => _page(
    HistoryCall(
      endpoint: 'history',
      branchId: branchId,
      dateFrom: dateFrom,
      dateTo: dateTo,
      type: type,
      status: status,
      page: page,
    ),
  );

  @override
  Future<PagedResult<ObservationModel>> myHistory({
    String? branchId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? type,
    String? status,
    int page = 1,
    int perPage = 20,
  }) async => _page(
    HistoryCall(
      endpoint: 'mine',
      branchId: branchId,
      dateFrom: dateFrom,
      dateTo: dateTo,
      type: type,
      status: status,
      page: page,
    ),
  );

  @override
  Future<ObservationModel> submit({
    required String type,
    String? taskId,
    required String itemId,
    required String branchId,
    String? supplierId,
    String? batchNo,
    DateTime? expDateObserved,
    num? physicalQty,
    String? remarks,
    String? photoPath,
    required String idempotencyKey,
  }) async {
    submitCalls.add(
      SubmitCall(
        type: type,
        taskId: taskId,
        itemId: itemId,
        branchId: branchId,
        supplierId: supplierId,
        batchNo: batchNo,
        expDateObserved: expDateObserved,
        physicalQty: physicalQty,
        remarks: remarks,
        idempotencyKey: idempotencyKey,
      ),
    );
    if (submitGate != null) await submitGate!.future;
    if (submitError != null) throw submitError!;
    return ObservationModel(
      id: '${submitCalls.length}',
      type: type,
      itemId: itemId,
      branchId: branchId,
      idempotencyKey: idempotencyKey,
      status: 'pending',
      physicalQty: physicalQty,
    );
  }

  ObservationModel _reviewed(String id, String status) => ObservationModel(
    id: id,
    type: 'stock_count',
    itemId: '1',
    branchId: '1',
    idempotencyKey: 'k',
    status: status,
  );

  @override
  Future<ObservationModel> approve(
    String id, {
    num? approvedQty,
    String? remarks,
  }) async {
    reviewCalls.add('approve:$id:$approvedQty');
    return _reviewed(id, 'approved');
  }

  @override
  Future<ObservationModel> requestRecount(
    String id, {
    required String remarks,
  }) async {
    reviewCalls.add('recount:$id:$remarks');
    return _reviewed(id, 'recount_requested');
  }

  @override
  Future<ObservationModel> reject(String id, {required String remarks}) async {
    reviewCalls.add('reject:$id:$remarks');
    return _reviewed(id, 'rejected');
  }
}

class TaskListCall {
  TaskListCall(this.categoryValueId, this.brandId);
  final String? categoryValueId;
  final String? brandId;
}

class FakeTaskRepository extends TaskRepository {
  FakeTaskRepository() : super(apiClient: offlineApiClient());

  List<TaskModel> tasks = [];
  Object? listError;
  Completer<void>? listGate;
  final listCalls = <TaskListCall>[];

  TaskModel? detailTask;
  final statusCalls = <String>[];
  Object? statusError;

  final createCalls = <Map<String, dynamic>>[];
  Object? createError;

  List<CategoryModel> categoryList = const [
    CategoryModel(id: '5', name: 'Dog Food'),
    CategoryModel(id: '6', name: 'Cat Food'),
  ];
  List<BrandModel> brandList = const [
    BrandModel(id: '7', name: 'Royal Canin'),
    BrandModel(id: '8', name: 'Whiskas'),
  ];
  List<AssigneeModel> assigneeList = const [
    AssigneeModel(id: '11', name: 'Alice Staff', role: 'Staff'),
  ];

  @override
  Future<List<TaskModel>> myTasks({
    String? categoryValueId,
    String? brandId,
    String? status,
  }) async {
    listCalls.add(TaskListCall(categoryValueId, brandId));
    if (listGate != null) await listGate!.future;
    if (listError != null) throw listError!;
    return tasks
        .where(
          (t) =>
              (categoryValueId == null ||
                  t.categoryValueId == categoryValueId) &&
              (brandId == null || t.brandId == brandId),
        )
        .toList();
  }

  @override
  Future<TaskModel> detail(String id) async =>
      detailTask ?? tasks.firstWhere((t) => t.id == id);

  @override
  Future<TaskModel> updateStatus(String taskId, String status) async {
    statusCalls.add('$taskId:$status');
    if (statusError != null) throw statusError!;
    return detailTask!;
  }

  @override
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
    createCalls.add(
      TaskRepository.createBody(
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
    if (createError != null) throw createError!;
    return TaskModel(
      id: '99',
      branchId: branchId,
      title: title,
      assignedTo: assignedTo ?? (assignedToIds.isNotEmpty ? assignedToIds.first : '1'),
      priority: priority,
      status: 'pending',
    );
  }

  @override
  Future<List<CategoryModel>> categories() async => categoryList;

  @override
  Future<List<BrandModel>> brands({String? categoryValueId}) async => brandList;

  @override
  Future<List<AssigneeModel>> assignees(String branchId) async => assigneeList;
}

class FakeItemRepository extends ItemRepository {
  FakeItemRepository() : super(apiClient: offlineApiClient());

  List<ItemModel> catalogue = [];
  final scopedCalls = <String>[];

  @override
  Future<PagedResult<ItemModel>> searchScoped({
    String query = '',
    String? categoryValueId,
    String? brandId,
    int page = 1,
    int perPage = 20,
  }) async {
    scopedCalls.add('q=$query|cat=$categoryValueId|brand=$brandId');
    final matches = catalogue
        .where(
          (i) =>
              (categoryValueId == null ||
                  i.categoryValueId == categoryValueId) &&
              (brandId == null || i.brandId == brandId) &&
              (query.isEmpty ||
                  i.name.toLowerCase().contains(query.toLowerCase())),
        )
        .toList();
    return PagedResult(
      items: matches,
      currentPage: 1,
      lastPage: 1,
      total: matches.length,
    );
  }

  /// Keyed by item id; defaults to no batches (picker shows no batch option).
  Map<String, List<BatchModel>> batchesByItem = {};

  @override
  Future<List<BatchModel>> batches({
    required String itemId,
    required String branchId,
  }) async => batchesByItem[itemId] ?? const [];
}

/// Fake for the expiry-bucket settings screen's PUT /v1/expiry-buckets/settings.
class FakeExpiryBucketRepository extends ExpiryBucketRepository {
  FakeExpiryBucketRepository() : super(apiClient: ApiClient());

  List<ExpiryBucketModel> buckets = [];
  List<List<ExpiryBucketModel>> saveCalls = [];
  Object? saveError;

  @override
  Future<List<ExpiryBucketModel>> list() async => buckets;

  @override
  Future<List<ExpiryBucketModel>> updateSettings(
    List<ExpiryBucketModel> newBuckets,
  ) async {
    saveCalls.add(newBuckets);
    if (saveError != null) throw saveError!;
    buckets = newBuckets;
    return buckets;
  }
}

// ---------------------------------------------------------------------------
// Pump helper
// ---------------------------------------------------------------------------

/// Pumps [screen] as the initial route of a real [GoRouter] (so
/// `context.push`/`pushReplacement`/`pop` behave as in the app). Navigation
/// targets the screens under test use are registered as placeholder pages
/// that print the route + extra, e.g. `ROUTE:/scanner {mode: stock_count}`.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  required UserModel user,
  FakeObservationRepository? observations,
  FakeTaskRepository? tasks,
  FakeItemRepository? items,
  List<BranchModel>? branches,
  List<Override> overrides = const [],
  bool settle = true,
}) async {
  Widget placeholder(GoRouterState s) =>
      Scaffold(body: Text('ROUTE:${s.matchedLocation} ${s.extra ?? ''}'));

  final router = GoRouter(
    initialLocation: '/start',
    routes: [
      GoRoute(path: '/start', builder: (c, s) => screen),
      for (final path in [
        '/scanner',
        '/submission-confirmation',
        '/review/:id',
        '/tasks/new',
        '/tasks/:id',
        '/home',
      ])
        GoRoute(path: path, builder: (c, s) => placeholder(s)),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith((ref) => FakeAuthController(user)),
        observationRepositoryProvider.overrideWithValue(
          observations ?? FakeObservationRepository(),
        ),
        taskRepositoryProvider.overrideWithValue(tasks ?? FakeTaskRepository()),
        itemRepositoryProvider.overrideWithValue(items ?? FakeItemRepository()),
        branchesProvider.overrideWith(
          (ref) async =>
              branches ?? [BranchModel(id: '1', name: 'Main Branch')],
        ),
        ...overrides,
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// A tall phone viewport so long forms/lists don't need scrolling for taps.
void useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

ObservationModel obs({
  required String id,
  String type = 'stock_count',
  String itemName = 'Royal Canin Adult Dog 15kg',
  String status = 'pending',
  num? physicalQty = 18,
  num? systemQty,
  String? submittedByName,
  String? batchNo,
}) => ObservationModel(
  id: id,
  type: type,
  itemId: '100$id',
  itemName: itemName,
  branchId: '1',
  branchName: 'Main Branch',
  idempotencyKey: 'key-$id',
  status: status,
  physicalQty: physicalQty,
  systemQtySnapshot: systemQty,
  submittedBy: '11',
  submittedByName: submittedByName,
  batchNo: batchNo,
  createdAt: DateTime(2025, 4, 24, 10, 24),
);

class FakeRiderOrderRepository extends RiderOrderRepository {
  FakeRiderOrderRepository({List<RiderOrderModel>? initialOrders})
      : orders = initialOrders ?? [];

  List<RiderOrderModel> orders;

  @override
  Future<List<RiderOrderModel>> fetchTodayDeliveries({String? status}) async {
    if (status != null && status.isNotEmpty) {
      return orders.where((o) => o.status == status).toList();
    }
    return List.from(orders);
  }

  @override
  Future<RiderOrderModel> updateStatus(
    int orderId, {
    required String status,
    double? startingKm,
    double? endingKm,
    String? deliveryDate,
    String? paymentStatus,
    String? paymentNote,
    String? notes,
  }) async {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx < 0) throw Exception('Order not found');
    final old = orders[idx];
    final updated = RiderOrderModel(
      id: old.id,
      invoiceNo: old.invoiceNo,
      invoiceDate: old.invoiceDate,
      deliveryDate: deliveryDate != null
          ? DateTime.tryParse(deliveryDate)
          : old.deliveryDate,
      status: status,
      statusLabel: status.replaceAll('_', ' ').toUpperCase(),
      totalAmount: old.totalAmount,
      paymentStatus: paymentStatus ?? old.paymentStatus,
      paymentNote: paymentNote ?? old.paymentNote,
      startingKm: startingKm ?? old.startingKm,
      endingKm: endingKm ?? old.endingKm,
      kmTravelled: (endingKm != null && (startingKm ?? old.startingKm) != null)
          ? endingKm - (startingKm ?? old.startingKm)!
          : old.kmTravelled,
      notes: notes ?? old.notes,
      deliveryNote: notes ?? old.deliveryNote,
      customerName: old.customerName,
      customerPhone: old.customerPhone,
      streetAddress: old.streetAddress,
      area: old.area,
      postcode: old.postcode,
      googleMapLink: old.googleMapLink,
      vehicleId: old.vehicleId,
      vehicleRegistration: old.vehicleRegistration,
      branchTitle: old.branchTitle,
    );
    orders[idx] = updated;
    return updated;
  }

  @override
  Future<List<VehicleModel>> fetchVehicles() async {
    return const [
      VehicleModel(
        id: 1,
        registrationNumber: 'GJ-01-AB-1234',
        make: 'Honda',
        model: 'Activa 6G',
        type: 'two_wheeler',
      ),
      VehicleModel(
        id: 2,
        registrationNumber: 'GJ-01-XY-9876',
        make: 'TVS',
        model: 'Jupiter',
        type: 'two_wheeler',
      ),
    ];
  }

  @override
  Future<void> assignVehicle(int orderId, int vehicleId) async {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx >= 0) {
      final old = orders[idx];
      orders[idx] = old.copyWith(
        vehicleId: vehicleId,
        vehicleRegistration: vehicleId == 1 ? 'GJ-01-AB-1234' : 'GJ-01-XY-9876',
      );
    }
  }
}

RiderOrderModel riderOrderFixture({
  required int id,
  String invoiceNo = 'INV-1001',
  String status = 'assigned',
  String statusLabel = 'Assigned',
  double totalAmount = 1450.0,
  String paymentStatus = 'cash',
  String customerName = 'Rahul Sharma',
  String customerPhone = '9876543210',
  String streetAddress = 'Flat 402, Royal Residency',
  String area = 'Satellite',
  String postcode = '380015',
  String? googleMapLink,
  double? startingKm,
  double? endingKm,
}) => RiderOrderModel(
  id: id,
  invoiceNo: invoiceNo,
  invoiceDate: DateTime.now(),
  deliveryDate: DateTime.now(),
  status: status,
  statusLabel: statusLabel,
  totalAmount: totalAmount,
  paymentStatus: paymentStatus,
  startingKm: startingKm,
  endingKm: endingKm,
  customerName: customerName,
  customerPhone: customerPhone,
  streetAddress: streetAddress,
  area: area,
  postcode: postcode,
  googleMapLink: googleMapLink,
);
