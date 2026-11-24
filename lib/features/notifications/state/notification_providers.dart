import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../auth/state/auth_providers.dart';
import '../data/notification_model.dart';
import '../data/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(apiClientProvider));
});

class NotificationState {
  const NotificationState({
    this.isLoading = false,
    this.notifications = const [],
    this.unreadCount = 0,
    this.errorMessage,
  });

  final bool isLoading;
  final List<NotificationModel> notifications;
  final int unreadCount;
  final String? errorMessage;

  NotificationState copyWith({
    bool? isLoading,
    List<NotificationModel>? notifications,
    int? unreadCount,
    String? errorMessage,
  }) {
    return NotificationState(
      isLoading: isLoading ?? this.isLoading,
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      errorMessage: errorMessage,
    );
  }
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  NotificationNotifier(this._repository) : super(const NotificationState()) {
    refresh();
  }

  final NotificationRepository _repository;

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final list = await _repository.fetchNotifications();
      final count = await _repository.fetchUnreadCount();
      state = state.copyWith(
        isLoading: false,
        notifications: list,
        unreadCount: count,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> markRead(int id) async {
    try {
      await _repository.markAsRead(id);
      final updated = state.notifications.map((n) {
        if (n.id == id) return n.copyWith(isRead: true);
        return n;
      }).toList();
      final unread = updated.where((n) => !n.isRead).length;
      state = state.copyWith(notifications: updated, unreadCount: unread);
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      await _repository.markAllAsRead();
      final updated = state.notifications.map((n) => n.copyWith(isRead: true)).toList();
      state = state.copyWith(notifications: updated, unreadCount: 0);
    } catch (_) {}
  }
}

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier(ref.watch(notificationRepositoryProvider));
});
