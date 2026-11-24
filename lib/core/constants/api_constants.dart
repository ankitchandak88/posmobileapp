/// API base URL is injected via --dart-define=API_BASE_URL=... at build/run
/// time. Default points at the Android emulator's loopback alias for a
/// local Laravel dev server (`php artisan serve` on port 8000).
///
/// Example:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
class ApiConstants {
  ApiConstants._();

  /// Environment URL presets
  static const String stagingRamdevUrl = 'https://pos.ramdevcar.shop/api/v1';
  static const String liveIndianPetsUrl = 'https://pos.indianpetcompany.com/api/v1';

  /// Rider Delivery API URL (Indian-Pet-Company CRM)
  static const String riderDeliveryUrl = 'https://urban.indianpetcompany.com/api/v1';

  /// Active base URL:
  /// - Live IndianPets server (https://pos.indianpetcompany.com/api/v1)
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: liveIndianPetsUrl,
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);

  // Auth
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String me = '/me';

  // Reference data
  static const String branches = '/branches';
  static const String expiryBuckets = '/expiry-buckets';
  static const String expiryBucketSettings = '/expiry-buckets/settings';
  static const String categories = '/categories';
  static const String brands = '/brands';
  static const String suppliers = '/suppliers';

  // Dashboard
  static const String dashboardSummary = '/dashboard/summary';

  // Items
  static const String itemsSearch = '/items/search';
  static String itemBarcode(String code) => '/items/barcode/$code';
  static String itemBatches(String itemId) => '/items/$itemId/batches';

  // Tasks
  static const String tasks = '/tasks';
  static const String taskAssignees = '/tasks/assignees';
  static String taskDetail(String id) => '/tasks/$id';
  static String taskStatus(String id) => '/tasks/$id/status';

  // Observations
  static const String observations = '/observations';
  static const String observationsMine = '/observations/mine';
  static const String observationsPending = '/observations/pending';
  static String observationApprove(String id) => '/observations/$id/approve';
  static String observationRequestRecount(String id) =>
      '/observations/$id/request-recount';
  static String observationReject(String id) => '/observations/$id/reject';
  static String observationDetail(String id) => '/observations/$id';
  static String observationPhoto(String id) => '/observations/$id/photo';

  // Barcode mapping
  static const String barcodeMappingRequests = '/barcode-mapping-requests';
  static String barcodeMappingApprove(String id) =>
      '/barcode-mapping-requests/$id/approve';
  static String barcodeMappingReject(String id) =>
      '/barcode-mapping-requests/$id/reject';

  // Notifications
  static const String notifications = '/notifications';
  static const String notificationsUnreadCount = '/notifications/unread-count';
  static String notificationRead(int id) => '/notifications/$id/read';
  static const String notificationsReadAll = '/notifications/read-all';

  // Purchases
  static String purchaseItemLookup(String code) => '/purchases/item-lookup/$code';

  // Rider endpoints (Indian-Pet-Company CRM)
  static const String riderOrders = '/orders';
  static String riderOrderDetail(int id) => '/orders/$id';
  static String riderOrderStatus(int id) => '/orders/$id/status';
  static String riderAssignVehicle(int id) => '/orders/$id/assign-vehicle';
  static const String riderVehicles = '/vehicles';
}
