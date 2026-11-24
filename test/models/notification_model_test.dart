import 'package:flutter_test/flutter_test.dart';
import 'package:urban_pets_verify/features/notifications/data/notification_model.dart';

void main() {
  group('NotificationModel JSON parsing', () {
    test('parses task_assigned notification correctly', () {
      final json = {
        'id': 1,
        'title': 'New Task Assigned',
        'message': 'You have been assigned: Count Dog Food',
        'type': 'task_assigned',
        'data': {
          'task_id': 42,
          'title': 'Count Dog Food',
          'priority': 'high',
        },
        'is_read': false,
        'created_at': '2026-11-04T10:00:00Z',
      };

      final model = NotificationModel.fromJson(json);

      expect(model.id, 1);
      expect(model.title, 'New Task Assigned');
      expect(model.message, 'You have been assigned: Count Dog Food');
      expect(model.type, 'task_assigned');
      expect(model.isRead, isFalse);
      expect(model.data?['task_id'], 42);
      expect(model.createdAt, isNotNull);
    });

    test('copyWith updates isRead state', () {
      const model = NotificationModel(
        id: 2,
        title: 'Recount Requested',
        message: 'Please recount item',
        type: 'recount_requested',
        isRead: false,
      );

      final updated = model.copyWith(isRead: true);
      expect(updated.isRead, isTrue);
      expect(updated.id, 2);
    });
  });
}

