import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/parse_helpers.dart';
import 'notification_model.dart';

class NotificationRepository {
  NotificationRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<NotificationModel>> fetchNotifications() async {
    final response = await _apiClient.request(ApiConstants.notifications);
    final raw = response.data;
    List<dynamic> items = [];
    if (raw is Map && raw['data'] is List) {
      items = raw['data'] as List<dynamic>;
    } else if (raw is List) {
      items = raw;
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(NotificationModel.fromJson)
        .toList();
  }

  Future<int> fetchUnreadCount() async {
    final response = await _apiClient.request(ApiConstants.notificationsUnreadCount);
    if (response.data is Map && response.data['unread_count'] != null) {
      return parseInt(response.data['unread_count']) ?? 0;
    }
    return 0;
  }

  Future<void> markAsRead(int id) async {
    await _apiClient.request(
      ApiConstants.notificationRead(id),
      method: 'POST',
    );
  }

  Future<void> markAllAsRead() async {
    await _apiClient.request(
      ApiConstants.notificationsReadAll,
      method: 'POST',
    );
  }
}
